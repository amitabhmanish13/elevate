#!/usr/bin/env node

/**
 * MCP Flight Booking Server
 * 
 * This server provides flight booking capabilities through the Model Context Protocol.
 * It can be used with AI assistants to help users search and book flights with contextual awareness.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

// Mock flight data for demonstration
const MOCK_FLIGHTS = {
  'JFK-LAX': [
    {
      id: 'FL001',
      airline: 'American Airlines',
      flightNumber: 'AA1234',
      departure: { airport: 'JFK', city: 'New York', time: '08:00', terminal: '4' },
      arrival: { airport: 'LAX', city: 'Los Angeles', time: '11:30', terminal: '3' },
      duration: '6h 30m',
      price: 450,
      currency: 'USD',
      stops: 0,
      aircraft: 'Boeing 777-300ER',
      class: 'economy',
      amenities: ['wifi', 'entertainment', 'meal']
    },
    {
      id: 'FL002',
      airline: 'Delta Air Lines',
      flightNumber: 'DL5678',
      departure: { airport: 'JFK', city: 'New York', time: '14:15', terminal: '2' },
      arrival: { airport: 'LAX', city: 'Los Angeles', time: '17:45', terminal: '1' },
      duration: '6h 30m',
      price: 425,
      currency: 'USD',
      stops: 0,
      aircraft: 'Airbus A350-900',
      class: 'economy',
      amenities: ['wifi', 'entertainment', 'meal', 'insurance']
    }
  ],
  'LHR-JFK': [
    {
      id: 'FL003',
      airline: 'British Airways',
      flightNumber: 'BA117',
      departure: { airport: 'LHR', city: 'London', time: '10:45', terminal: '5' },
      arrival: { airport: 'JFK', city: 'New York', time: '14:20', terminal: '7' },
      duration: '8h 35m',
      price: 650,
      currency: 'USD',
      stops: 0,
      aircraft: 'Boeing 787-9',
      class: 'economy',
      amenities: ['wifi', 'entertainment', 'meal']
    }
  ]
};

const USER_CONTEXT = {
  searchHistory: [],
  preferredAirlines: [],
  budgetRange: { min: 0, max: 10000 },
  frequentDestinations: [],
  userPreferences: {
    seatPreference: 'window',
    mealPreference: [],
    accessibilityNeeds: []
  }
};

class FlightBookingServer {
  constructor() {
    this.server = new Server(
      {
        name: 'flight-booking-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
          resources: {},
        },
      }
    );

    this.setupToolHandlers();
    this.setupResourceHandlers();
    
    // Error handling
    this.server.onerror = (error) => {
      console.error('[MCP Error]', error);
    };

    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'search_flights',
            description: 'Search for flights between two airports with specified criteria',
            inputSchema: {
              type: 'object',
              properties: {
                from: {
                  type: 'string',
                  description: 'Departure airport code (e.g., JFK, LAX, LHR)',
                },
                to: {
                  type: 'string',
                  description: 'Arrival airport code (e.g., JFK, LAX, LHR)',
                },
                departure_date: {
                  type: 'string',
                  description: 'Departure date in YYYY-MM-DD format',
                },
                return_date: {
                  type: 'string',
                  description: 'Return date in YYYY-MM-DD format (for round trip)',
                },
                passengers: {
                  type: 'number',
                  description: 'Number of passengers (1-9)',
                  minimum: 1,
                  maximum: 9,
                },
                class: {
                  type: 'string',
                  enum: ['economy', 'business', 'first'],
                  description: 'Cabin class preference',
                },
                trip_type: {
                  type: 'string',
                  enum: ['oneWay', 'roundTrip'],
                  description: 'Type of trip',
                },
              },
              required: ['from', 'to', 'departure_date', 'passengers', 'class', 'trip_type'],
            },
          },
          {
            name: 'get_flight_details',
            description: 'Get detailed information about a specific flight',
            inputSchema: {
              type: 'object',
              properties: {
                flight_id: {
                  type: 'string',
                  description: 'Unique flight identifier',
                },
              },
              required: ['flight_id'],
            },
          },
          {
            name: 'book_flight',
            description: 'Book a selected flight with passenger information',
            inputSchema: {
              type: 'object',
              properties: {
                flight_id: {
                  type: 'string',
                  description: 'Flight ID to book',
                },
                passengers: {
                  type: 'array',
                  description: 'Passenger information',
                  items: {
                    type: 'object',
                    properties: {
                      title: { type: 'string', enum: ['Mr', 'Ms', 'Mrs', 'Dr'] },
                      firstName: { type: 'string' },
                      lastName: { type: 'string' },
                      dateOfBirth: { type: 'string' },
                      email: { type: 'string' },
                      phone: { type: 'string' },
                    },
                    required: ['title', 'firstName', 'lastName', 'dateOfBirth', 'email', 'phone'],
                  },
                },
                contact_info: {
                  type: 'object',
                  properties: {
                    email: { type: 'string' },
                    phone: { type: 'string' },
                  },
                  required: ['email', 'phone'],
                },
              },
              required: ['flight_id', 'passengers', 'contact_info'],
            },
          },
          {
            name: 'get_user_preferences',
            description: 'Get user travel preferences and context',
            inputSchema: {
              type: 'object',
              properties: {},
            },
          },
          {
            name: 'update_user_preferences',
            description: 'Update user travel preferences',
            inputSchema: {
              type: 'object',
              properties: {
                preferred_airlines: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'List of preferred airline names',
                },
                budget_range: {
                  type: 'object',
                  properties: {
                    min: { type: 'number' },
                    max: { type: 'number' },
                  },
                },
                seat_preference: {
                  type: 'string',
                  enum: ['window', 'aisle', 'middle'],
                },
                meal_preferences: {
                  type: 'array',
                  items: { type: 'string' },
                },
              },
            },
          },
        ],
      };
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'search_flights':
            return await this.searchFlights(args);
          case 'get_flight_details':
            return await this.getFlightDetails(args);
          case 'book_flight':
            return await this.bookFlight(args);
          case 'get_user_preferences':
            return await this.getUserPreferences();
          case 'update_user_preferences':
            return await this.updateUserPreferences(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
        };
      }
    });
  }

  setupResourceHandlers() {
    // List available resources
    this.server.setRequestHandler(ListResourcesRequestSchema, async () => {
      return {
        resources: [
          {
            uri: 'flight://context/user',
            name: 'User Travel Context',
            description: 'Current user travel preferences and history',
            mimeType: 'application/json',
          },
          {
            uri: 'flight://data/airports',
            name: 'Airport Database',
            description: 'Available airports and their information',
            mimeType: 'application/json',
          },
        ],
      };
    });

    // Handle resource reads
    this.server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      const { uri } = request.params;

      switch (uri) {
        case 'flight://context/user':
          return {
            contents: [
              {
                uri,
                mimeType: 'application/json',
                text: JSON.stringify(USER_CONTEXT, null, 2),
              },
            ],
          };
        case 'flight://data/airports':
          return {
            contents: [
              {
                uri,
                mimeType: 'application/json',
                text: JSON.stringify({
                  airports: [
                    { code: 'JFK', name: 'John F. Kennedy International', city: 'New York', country: 'USA' },
                    { code: 'LAX', name: 'Los Angeles International', city: 'Los Angeles', country: 'USA' },
                    { code: 'LHR', name: 'Heathrow', city: 'London', country: 'UK' },
                    { code: 'CDG', name: 'Charles de Gaulle', city: 'Paris', country: 'France' },
                    { code: 'NRT', name: 'Narita International', city: 'Tokyo', country: 'Japan' },
                    { code: 'DXB', name: 'Dubai International', city: 'Dubai', country: 'UAE' },
                  ]
                }, null, 2),
              },
            ],
          };
        default:
          throw new Error(`Unknown resource: ${uri}`);
      }
    });
  }

  async searchFlights(args) {
    const { from, to, departure_date, return_date, passengers, class: flightClass, trip_type } = args;
    
    // Update user context with search
    USER_CONTEXT.searchHistory.unshift({
      from, to, departure_date, return_date, passengers, class: flightClass, trip_type,
      timestamp: new Date().toISOString()
    });
    
    // Keep only last 10 searches
    USER_CONTEXT.searchHistory = USER_CONTEXT.searchHistory.slice(0, 10);

    const route = `${from}-${to}`;
    const outboundFlights = MOCK_FLIGHTS[route] || [];
    
    // Generate some realistic variations
    const flights = outboundFlights.map(flight => ({
      ...flight,
      price: Math.round(flight.price * (0.8 + Math.random() * 0.4) * passengers),
      availableSeats: Math.floor(Math.random() * 50) + 10,
    }));

    let returnFlights = [];
    if (trip_type === 'roundTrip' && return_date) {
      const returnRoute = `${to}-${from}`;
      returnFlights = (MOCK_FLIGHTS[returnRoute] || []).map(flight => ({
        ...flight,
        price: Math.round(flight.price * (0.8 + Math.random() * 0.4) * passengers),
        availableSeats: Math.floor(Math.random() * 50) + 10,
      }));
    }

    // AI recommendations based on context
    const recommendations = this.generateRecommendations(args);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            outbound: flights,
            return: returnFlights,
            total_results: flights.length + returnFlights.length,
            recommendations,
            search_context: {
              user_previous_searches: USER_CONTEXT.searchHistory.length,
              preferred_airlines: USER_CONTEXT.preferredAirlines,
              budget_range: USER_CONTEXT.budgetRange,
            }
          }, null, 2),
        },
      ],
    };
  }

  async getFlightDetails(args) {
    const { flight_id } = args;
    
    // Find flight in mock data
    for (const route of Object.values(MOCK_FLIGHTS)) {
      const flight = route.find(f => f.id === flight_id);
      if (flight) {
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                flight,
                booking_context: this.buildBookingContext(flight),
              }, null, 2),
            },
          ],
        };
      }
    }

    throw new Error(`Flight ${flight_id} not found`);
  }

  async bookFlight(args) {
    const { flight_id, passengers, contact_info } = args;
    
    // Simulate booking process
    const bookingReference = `BK${Date.now().toString().slice(-6)}${Math.random().toString(36).substr(2, 3).toUpperCase()}`;
    
    // Update user preferences based on booking
    const flight = await this.findFlightById(flight_id);
    if (flight) {
      if (!USER_CONTEXT.preferredAirlines.includes(flight.airline)) {
        USER_CONTEXT.preferredAirlines.push(flight.airline);
      }
      USER_CONTEXT.frequentDestinations.push(flight.arrival.airport);
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            booking_reference: bookingReference,
            status: 'confirmed',
            flight_id,
            passengers: passengers.length,
            total_price: flight ? flight.price * passengers.length : 0,
            confirmation: {
              email_sent: contact_info.email,
              sms_sent: contact_info.phone,
            }
          }, null, 2),
        },
      ],
    };
  }

  async getUserPreferences() {
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(USER_CONTEXT, null, 2),
        },
      ],
    };
  }

  async updateUserPreferences(args) {
    const { preferred_airlines, budget_range, seat_preference, meal_preferences } = args;
    
    if (preferred_airlines) {
      USER_CONTEXT.preferredAirlines = [...new Set([...USER_CONTEXT.preferredAirlines, ...preferred_airlines])];
    }
    if (budget_range) {
      USER_CONTEXT.budgetRange = budget_range;
    }
    if (seat_preference) {
      USER_CONTEXT.userPreferences.seatPreference = seat_preference;
    }
    if (meal_preferences) {
      USER_CONTEXT.userPreferences.mealPreference = meal_preferences;
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            message: 'Preferences updated successfully',
            updated_preferences: USER_CONTEXT
          }, null, 2),
        },
      ],
    };
  }

  generateRecommendations(searchArgs) {
    const recommendations = [];
    
    // Based on search history
    if (USER_CONTEXT.searchHistory.length > 0) {
      recommendations.push("💡 Based on your search history, consider flexible dates for better prices");
    }
    
    // Based on preferred airlines
    if (USER_CONTEXT.preferredAirlines.length > 0) {
      recommendations.push(`✈️ Your preferred airlines (${USER_CONTEXT.preferredAirlines.join(', ')}) may have options on this route`);
    }
    
    // Based on budget
    if (searchArgs.class === 'economy' && USER_CONTEXT.budgetRange.max > 1000) {
      recommendations.push("🎯 Consider premium economy for better comfort within your budget");
    }
    
    return recommendations;
  }

  buildBookingContext(flight) {
    return {
      protocol_version: "1.0",
      model: "flight-booking-assistant",
      timestamp: new Date().toISOString(),
      system_context: {
        role: "AI Flight Booking Assistant",
        guidelines: [
          "Guide users through the booking process step by step",
          "Ensure all required information is collected",
          "Verify booking details before confirmation"
        ]
      },
      user_context: USER_CONTEXT,
      task_context: {
        task_type: "flight_booking",
        specific_request: `Book flight ${flight.flightNumber}`,
        constraints: {
          flight_id: flight.id,
          total_price: flight.price
        }
      }
    };
  }

  async findFlightById(flightId) {
    for (const route of Object.values(MOCK_FLIGHTS)) {
      const flight = route.find(f => f.id === flightId);
      if (flight) return flight;
    }
    return null;
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('MCP Flight Booking Server running on stdio');
  }
}

const server = new FlightBookingServer();
server.run().catch(console.error);