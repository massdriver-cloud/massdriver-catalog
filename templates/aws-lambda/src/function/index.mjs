// Replace this handler with your application code.
// The scaffold responds to any request with a JSON greeting.

export const handler = async (event) => {
  const method = event.requestContext?.http?.method ?? "GET";
  const path = event.rawPath ?? "/";

  return {
    statusCode: 200,
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      message: "Your function is live. Replace src/function/index.mjs with your app.",
      method,
      path,
    }),
  };
};
