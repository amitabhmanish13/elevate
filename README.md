# Flight Booking App with MCP Integration

A modern, AI-powered flight booking web application built with **Model Context Protocol (MCP)** integration. This application demonstrates how MCP can be used to create context-aware, personalized user experiences in travel booking.

## 🌟 Features

### Core Functionality
- **Flight Search**: Search for flights between major airports worldwide
- **Round-trip & One-way**: Support for both trip types
- **Multiple Classes**: Economy, Business, and First class options
- **Real-time Results**: Dynamic flight data with pricing
- **Interactive Booking**: Complete booking flow with passenger management

### MCP-Powered AI Features
- **Personalized Recommendations**: AI suggestions based on search history
- **Context-Aware Search**: Remembers user preferences and frequent destinations
- **Smart Filtering**: Automatic filters based on user behavior patterns
- **Budget Intelligence**: Price recommendations within user's budget range
- **Airline Preferences**: Learns and suggests preferred airlines

### Modern UI/UX
- **Responsive Design**: Works on desktop, tablet, and mobile
- **Modern Interface**: Clean, intuitive design with Tailwind CSS
- **Real-time Updates**: Dynamic content updates without page refresh
- **Accessibility**: Built with accessibility best practices
- **Loading States**: Smooth loading animations and feedback

## 🏗️ Architecture

### Frontend Stack
- **React 19** with TypeScript
- **Tailwind CSS** for styling
- **Lucide React** for icons
- **date-fns** for date handling
- **Vite** for build tooling

### Backend Stack
- **Go** with Gin framework
- **RESTful API** design
- **JSON response format**

### MCP Integration
- **Model Context Protocol** for AI context management
- **Context Persistence** with localStorage
- **Structured Context Data** for optimal AI performance
- **Real-time Context Updates** based on user interactions

## 🚀 Getting Started

### Prerequisites
- Node.js (v18 or higher)
- Go (v1.19 or higher)
- npm or yarn

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd flight-booking-app
   ```

2. **Install Frontend Dependencies**
   ```bash
   cd frontend
   npm install --legacy-peer-deps
   ```

3. **Install Backend Dependencies**
   ```bash
   cd ../backend
   go mod tidy
   ```

4. **Install MCP Dependencies** (Optional - for AI assistant integration)
   ```bash
   npm install -g @modelcontextprotocol/sdk
   ```

### Running the Application

1. **Start the Backend Server**
   ```bash
   cd backend
   go run main.go
   ```
   Backend will run on `http://localhost:8080`

2. **Start the Frontend Development Server**
   ```bash
   cd frontend
   npm run dev
   ```
   Frontend will run on `http://localhost:5173`

3. **Run MCP Server** (Optional - for AI assistant integration)
   ```bash
   node mcp-flight-server.js
   ```

## 🤖 MCP Integration

### What is MCP?

Model Context Protocol (MCP) is an open-source protocol developed by Anthropic that enables AI models to connect to external data sources and tools. It provides a standardized way to manage context and enable AI assistants to perform specific tasks.

### How This App Uses MCP

1. **Context Management**: Stores user preferences, search history, and behavior patterns
2. **Personalized Recommendations**: AI analyzes context to provide relevant suggestions
3. **Smart Defaults**: Pre-fills forms based on user's previous interactions
4. **Contextual Filtering**: Applies intelligent filters based on user patterns

### MCP Context Structure

```json
{
  "protocol_version": "1.0",
  "system_context": {
    "role": "AI Flight Booking Assistant",
    "guidelines": ["Provide personalized recommendations", "Consider user budget"],
    "constraints": ["Real-time data only", "Secure booking process"]
  },
  "user_context": {
    "searchHistory": [],
    "preferredAirlines": [],
    "budgetRange": { "min": 0, "max": 10000 },
    "frequentDestinations": [],
    "userPreferences": {
      "seatPreference": "window",
      "mealPreference": [],
      "accessibilityNeeds": []
    }
  },
  "task_context": {
    "task_type": "flight_search",
    "specific_request": "Find flights from JFK to LAX",
    "output_format": "structured_flight_results"
  }
}
```

### Using with AI Assistants

To use this MCP server with Claude or other AI assistants:

1. **Configure MCP Client** (in your AI assistant):
   ```json
   {
     "mcpServers": {
       "flight-booking": {
         "command": "node",
         "args": ["mcp-flight-server.js"],
         "env": {}
       }
     }
   }
   ```

2. **Available Tools**:
   - `search_flights`: Search for flights with specified criteria
   - `get_flight_details`: Get detailed information about a specific flight
   - `book_flight`: Book a selected flight with passenger information
   - `get_user_preferences`: Retrieve user travel preferences
   - `update_user_preferences`: Update user travel preferences

3. **Example Usage**:
   ```
   User: "Find me flights from New York to Los Angeles next Friday"
   AI Assistant: Uses MCP to search flights, considers user's preferences, and provides personalized recommendations
   ```

## 📱 Usage Examples

### Basic Flight Search
1. Enter departure and arrival airports
2. Select travel dates
3. Choose number of passengers and class
4. Click "Search Flights"
5. Browse results with AI recommendations

### AI-Powered Features
- **Smart Suggestions**: Based on search history, the app suggests similar routes
- **Budget Recommendations**: AI suggests flight classes within your budget
- **Airline Preferences**: System learns your preferred airlines over time
- **Flexible Dates**: AI recommends date adjustments for better prices

### Booking Process
1. Select desired flights (outbound and return for round trips)
2. Review total price and flight details
3. Click "Continue to Booking"
4. Enter passenger information
5. Complete payment and receive confirmation

## 🔧 Configuration

### Environment Variables
Create a `.env` file in the frontend directory:

```env
VITE_API_BASE_URL=http://localhost:8080
VITE_MCP_ENABLED=true
VITE_DEBUG_MODE=false
```

### MCP Configuration
The MCP client can be configured in `frontend/src/services/mcpClient.ts`:

```typescript
// Adjust context retention settings
const MAX_SEARCH_HISTORY = 10;
const CONTEXT_EXPIRY_DAYS = 30;

// Configure AI recommendation thresholds
const RECOMMENDATION_CONFIDENCE_THRESHOLD = 0.7;
```

## 🛠️ Development

### Project Structure
```
flight-booking-app/
├── frontend/                 # React frontend application
│   ├── src/
│   │   ├── components/      # React components
│   │   ├── services/        # API and MCP services
│   │   ├── types/          # TypeScript type definitions
│   │   └── assets/         # Static assets
│   ├── public/             # Public assets
│   └── package.json        # Frontend dependencies
├── backend/                 # Go backend API
│   ├── main.go             # Main server file
│   ├── go.mod              # Go module definition
│   └── go.sum              # Go dependencies
├── mcp-flight-server.js    # MCP server implementation
└── README.md               # This file
```

### Adding New Features

1. **Frontend Components**: Add new React components in `frontend/src/components/`
2. **API Endpoints**: Add new endpoints in `backend/main.go`
3. **MCP Tools**: Add new tools in `mcp-flight-server.js`
4. **Types**: Define new TypeScript types in `frontend/src/types/`

### Testing

```bash
# Frontend tests
cd frontend
npm run test

# Backend tests
cd backend
go test ./...

# MCP server tests
node test-mcp-server.js
```

## 🔒 Security

- **Data Encryption**: All sensitive data is encrypted in transit
- **Input Validation**: Comprehensive validation on all user inputs
- **Secure Storage**: User preferences stored securely in localStorage
- **API Rate Limiting**: Backend includes rate limiting for API calls
- **Context Privacy**: MCP context data is kept private and secure

## 🚢 Deployment

### Frontend Deployment
```bash
cd frontend
npm run build
# Deploy the 'dist' directory to your web server
```

### Backend Deployment
```bash
cd backend
go build -o flight-booking-server main.go
# Deploy the binary to your server
```

### MCP Server Deployment
```bash
# Deploy as a service or containerize with Docker
node mcp-flight-server.js
```

## 📖 API Documentation

### Flight Search API
```
POST /api/flights/search
{
  "from": "JFK",
  "to": "LAX", 
  "departureDate": "2024-07-15",
  "returnDate": "2024-07-22",
  "passengers": 2,
  "class": "economy"
}
```

### Booking API
```
POST /api/flights/book
{
  "flightId": "FL001",
  "passengers": [...],
  "contactInfo": {...}
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Anthropic** for developing the Model Context Protocol
- **React Team** for the excellent frontend framework
- **Tailwind CSS** for the utility-first CSS framework
- **Go Team** for the efficient backend language
- **Lucide** for the beautiful icon set

## 📞 Support

For support, email support@flightbooker.com or join our Slack channel.

---

**Built with ❤️ and powered by MCP**

