# WebUI Chat Application

A cross-platform Flutter desktop application for interacting with various AI models.

## Features

- **Multiple Model Support**: Connect to Groq, Anthropic (Claude), OpenAI, and Grok AI models
- **Dark/Light Theme**: Toggle between dark and light themes
- **File Attachments**: Send images and other files with your messages
- **Image Support**: Send images to vision-capable models (when enabled)
- **Chat History**: Automatically saves chat history
- **Responsive UI**: Works well on desktop environments (Windows, Linux)

## Getting Started

### Prerequisites

- Flutter SDK (2.5.0 or higher)
- Dart SDK (2.14.0 or higher)
- An API key from one of the supported model providers (Groq, Anthropic, OpenAI, or Grok)

### Installation

1. Clone this repository:
   ```
   git clone <repository-url>
   ```

2. Navigate to the project directory:
   ```
   cd webui
   ```

3. Install dependencies:
   ```
   flutter pub get
   ```

4. Run the application:
   ```
   flutter run -d windows
   ```
   or
   ```
   flutter run -d linux
   ```

## Usage

1. **Setting API Key**:
   - Click the settings icon in the top-right corner
   - Enter your API key and save

2. **Selecting a Model**:
   - Click the dropdown arrow next to the model name
   - Choose a model from the available list

3. **Sending Messages**:
   - Type your message in the input field
   - Press Enter or click the send button

4. **Attaching Files**:
   - Click the paper clip icon
   - Select files to attach (images, PDFs, text files, etc.)

5. **Toggling Theme**:
   - Click the sun/moon icon to switch between light and dark themes

## Image Support

To enable image sending to vision-capable models:
1. Go to Settings
2. Toggle "Enable Image Support"
3. Attach image files before sending your message

Note: Only certain models support image inputs (like GPT-4o, Claude 3 Opus, etc.)

## Troubleshooting

- **API Connection Issues**: Verify your API key is correct and check your internet connection
- **Missing UI Elements**: Make sure you're using the latest version of Flutter
- **File Attachment Problems**: Check that you have proper permissions for file access

## License

This project is licensed under the MIT License - see the LICENSE file for details.

