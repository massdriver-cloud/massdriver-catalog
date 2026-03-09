package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Todo struct {
	ID        int       `json:"id"`
	Title     string    `json:"title"`
	Completed bool      `json:"completed"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CreateTodoRequest struct {
	Title     string `json:"title" binding:"required"`
	Completed bool   `json:"completed"`
}

type UpdateTodoRequest struct {
	Title     *string `json:"title"`
	Completed *bool   `json:"completed"`
}

var (
	db      *pgxpool.Pool
	dbMutex sync.RWMutex
	dbReady bool
	dbError string
)

func main() {
	// Setup router first - start serving immediately
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	r.GET("/", healthCheck)
	r.GET("/health", healthCheck)
	r.GET("/todos", listTodos)
	r.POST("/todos", createTodo)
	r.GET("/todos/:id", getTodo)
	r.PUT("/todos/:id", updateTodo)
	r.DELETE("/todos/:id", deleteTodo)

	// Connect to database in background
	go connectDatabase()

	port := getEnvOrDefault("PORT", "8080")
	log.Printf("Server starting on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func connectDatabase() {
	ctx := context.Background()

	// Get database URL
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		// Build from individual components
		host := getEnvOrDefault("DATABASE_HOST", "localhost")
		port := getEnvOrDefault("DATABASE_PORT", "5432")
		name := getEnvOrDefault("DATABASE_NAME", "postgres")
		user := getEnvOrDefault("DATABASE_USER", "postgres")
		pass := os.Getenv("DATABASE_PASSWORD")
		if host == "localhost" && pass == "" {
			log.Printf("No database configured, running without persistence")
			dbMutex.Lock()
			dbError = "no database configured"
			dbMutex.Unlock()
			return
		}
		dbURL = fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable", user, pass, host, port, name)
	}

	log.Printf("Connecting to database...")

	// Retry connection
	var pool *pgxpool.Pool
	var err error
	for i := 0; i < 60; i++ {
		pool, err = pgxpool.New(ctx, dbURL)
		if err == nil {
			err = pool.Ping(ctx)
			if err == nil {
				break
			}
			pool.Close()
		}
		log.Printf("Waiting for database... (%d/60): %v", i+1, err)
		time.Sleep(time.Second)
	}

	if err != nil {
		log.Printf("Failed to connect to database: %v", err)
		dbMutex.Lock()
		dbError = err.Error()
		dbMutex.Unlock()
		return
	}

	// Create table
	_, err = pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS todos (
			id SERIAL PRIMARY KEY,
			title TEXT NOT NULL,
			completed BOOLEAN DEFAULT FALSE,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)
	`)
	if err != nil {
		log.Printf("Failed to create table: %v", err)
		dbMutex.Lock()
		dbError = err.Error()
		dbMutex.Unlock()
		pool.Close()
		return
	}

	// Set the global connection
	dbMutex.Lock()
	db = pool
	dbReady = true
	dbError = ""
	dbMutex.Unlock()

	log.Printf("Database connected and ready")
}

func getDB() (*pgxpool.Pool, error) {
	dbMutex.RLock()
	defer dbMutex.RUnlock()
	if !dbReady {
		if dbError != "" {
			return nil, fmt.Errorf("database error: %s", dbError)
		}
		return nil, fmt.Errorf("database not ready")
	}
	return db, nil
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func healthCheck(c *gin.Context) {
	dbMutex.RLock()
	ready := dbReady
	errMsg := dbError
	dbMutex.RUnlock()

	status := "healthy"
	dbStatus := "connected"
	if !ready {
		if errMsg != "" {
			dbStatus = "error: " + errMsg
		} else {
			dbStatus = "connecting"
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"status":   status,
		"service":  "todo-api",
		"database": dbStatus,
	})
}

func listTodos(c *gin.Context) {
	pool, err := getDB()
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": err.Error()})
		return
	}

	rows, err := pool.Query(c.Request.Context(), "SELECT id, title, completed, created_at, updated_at FROM todos ORDER BY id")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	var todos []Todo
	for rows.Next() {
		var t Todo
		if err := rows.Scan(&t.ID, &t.Title, &t.Completed, &t.CreatedAt, &t.UpdatedAt); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		todos = append(todos, t)
	}

	if todos == nil {
		todos = []Todo{}
	}
	c.JSON(http.StatusOK, todos)
}

func createTodo(c *gin.Context) {
	pool, err := getDB()
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": err.Error()})
		return
	}

	var req CreateTodoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var t Todo
	err = pool.QueryRow(c.Request.Context(),
		"INSERT INTO todos (title, completed) VALUES ($1, $2) RETURNING id, title, completed, created_at, updated_at",
		req.Title, req.Completed,
	).Scan(&t.ID, &t.Title, &t.Completed, &t.CreatedAt, &t.UpdatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, t)
}

func getTodo(c *gin.Context) {
	pool, err := getDB()
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": err.Error()})
		return
	}

	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	var t Todo
	err = pool.QueryRow(c.Request.Context(),
		"SELECT id, title, completed, created_at, updated_at FROM todos WHERE id = $1", id,
	).Scan(&t.ID, &t.Title, &t.Completed, &t.CreatedAt, &t.UpdatedAt)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "todo not found"})
		return
	}

	c.JSON(http.StatusOK, t)
}

func updateTodo(c *gin.Context) {
	pool, err := getDB()
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": err.Error()})
		return
	}

	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	var req UpdateTodoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get current todo
	var current Todo
	err = pool.QueryRow(c.Request.Context(),
		"SELECT id, title, completed, created_at, updated_at FROM todos WHERE id = $1", id,
	).Scan(&current.ID, &current.Title, &current.Completed, &current.CreatedAt, &current.UpdatedAt)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "todo not found"})
		return
	}

	// Apply updates
	if req.Title != nil {
		current.Title = *req.Title
	}
	if req.Completed != nil {
		current.Completed = *req.Completed
	}

	// Update in database
	var t Todo
	err = pool.QueryRow(c.Request.Context(),
		"UPDATE todos SET title = $1, completed = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING id, title, completed, created_at, updated_at",
		current.Title, current.Completed, id,
	).Scan(&t.ID, &t.Title, &t.Completed, &t.CreatedAt, &t.UpdatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, t)
}

func deleteTodo(c *gin.Context) {
	pool, err := getDB()
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": err.Error()})
		return
	}

	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	result, err := pool.Exec(c.Request.Context(), "DELETE FROM todos WHERE id = $1", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if result.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "todo not found"})
		return
	}

	c.Status(http.StatusNoContent)
}
