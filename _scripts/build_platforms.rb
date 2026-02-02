#!/usr/bin/env ruby

# Platform Definition Builder
#
# This script compiles platform definitions from their declarative massdriver.yaml
# format into the dist.json format expected by the Massdriver backend.
#
# This is an experimental format for massdriver.yaml for artifact definitions.
# We're bikeshedding the ideal developer experience here before implementing
# support for this format in the Massdriver backend. The goal is to design a
# clean, declarative authoring experience that compiles down to the existing
# backend contract.
#
# Structure:
#   platforms/{name}/massdriver.yaml  -> Source of truth (human-editable)
#   _dist/{name}.json                 -> Built artifact (auto-generated)

require 'json'
require 'yaml'
require 'base64'
require 'fileutils'

def process_platform(platform_dir)
  platform_name = File.basename(platform_dir)
  md_file = File.join(platform_dir, 'massdriver.yaml')

  unless File.exist?(md_file)
    puts "⚠️  Skipping #{platform_name}: No massdriver.yaml found"
    return
  end

  puts "📦 Building platform: #{platform_name}"

  # Load the massdriver.yaml
  config = YAML.load_file(md_file)

  # Build the $md block from top-level keys
  md_block = {
    'name' => config['name'],
    'label' => config['label'],
    'icon' => config['icon']
  }

  # Add containerRepositories if present
  if config['containerRepositories']
    md_block['containerRepositories'] = config['containerRepositories']
  end

  # Process UI configuration
  md_block['ui'] = {}
  if config['ui']
    # Copy direct UI fields
    md_block['ui']['connectionOrientation'] = config['ui']['connectionOrientation'] if config['ui']['connectionOrientation']
    md_block['ui']['environmentDefaultGroup'] = config['ui']['environmentDefaultGroup'] if config['ui']['environmentDefaultGroup']

    # Process instructions - read markdown files and base64 encode
    md_block['ui']['instructions'] = []
    if config['ui']['instructions']
      config['ui']['instructions'].each do |instruction|
        instruction_path = File.join(platform_dir, instruction['path'])
        if File.exist?(instruction_path)
          content = Base64.strict_encode64(File.read(instruction_path))
          md_block['ui']['instructions'] << {
            'label' => instruction['label'],
            'content' => content
          }
          puts "  ✓ Instruction added: #{instruction['label']}"
        else
          puts "  ⚠️  Instruction file not found: #{instruction['path']}"
        end
      end
    end
  end

  # Process export templates
  md_block['export'] = []
  if config['exports'] && config['exports'].any?
    config['exports'].each do |export|
      template_path = File.join(platform_dir, export['templatePath'])
      if File.exist?(template_path)
        content = Base64.strict_encode64(File.read(template_path))
        md_block['export'] << {
          'downloadButtonText' => export['downloadButtonText'],
          'fileFormat' => export['fileFormat'],
          'template' => content,
          'templateLang' => export['templateLang']
        }
        puts "  ✓ Export template added: #{export['downloadButtonText']}"
      else
        puts "  ⚠️  Export template not found: #{export['templatePath']}"
      end
    end
  end

  # Build the final dist structure
  dist = {
    '$md' => md_block
  }.merge(config['schema'])

  # Write the dist file to _dist directory
  dist_dir = '_dist'
  FileUtils.mkdir_p(dist_dir) unless Dir.exist?(dist_dir)
  dist_file = File.join(dist_dir, "#{config['name']}.json")
  File.write(dist_file, JSON.pretty_generate(dist))
  puts "  ✅ Built: #{dist_file}\n\n"
end

# Main execution
platforms_dir = 'platforms'

unless Dir.exist?(platforms_dir)
  puts "❌ Error: platforms/ directory not found"
  exit 1
end

puts "🏗️  Massdriver Platform Builder\n\n"

# Get enabled platforms from command line args, or default to all
enabled_platforms = ARGV.empty? ? nil : ARGV

if enabled_platforms
  puts "📋 Enabled platforms: #{enabled_platforms.join(', ')}\n\n"
  enabled_platforms.each do |platform|
    platform_dir = File.join(platforms_dir, platform)
    if File.directory?(platform_dir)
      process_platform(platform_dir)
    else
      puts "⚠️  Platform directory not found: #{platform}\n\n"
    end
  end
else
  puts "📋 Building all platforms\n\n"
  Dir.glob(File.join(platforms_dir, '*')).select { |f| File.directory?(f) }.each do |platform_dir|
    process_platform(platform_dir)
  end
end

puts "✨ All platforms built successfully!"
