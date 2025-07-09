import type { FlightSearchParams, MCPFlightContext, Flight, Booking } from '../types/flight';

export interface MCPContextData {
  protocol_version: string;
  model: string;
  timestamp: string;
  session_id: string;
  system_context: {
    role: string;
    guidelines: string[];
    constraints: string[];
  };
  user_context: MCPFlightContext;
  task_context: {
    task_type: string;
    specific_request: string;
    output_format: string;
    constraints?: Record<string, any>;
  };
  document_context: {
    references: Array<{
      title: string;
      source: string;
      content: string;
    }>;
  };
}

class MCPFlightClient {
  private context: MCPFlightContext;
  private sessionId: string;

  constructor() {
    this.sessionId = this.generateSessionId();
    this.context = this.loadUserContext();
  }

  private generateSessionId(): string {
    return `flight-session-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  private loadUserContext(): MCPFlightContext {
    const saved = localStorage.getItem('mcpFlightContext');
    if (saved) {
      try {
        return JSON.parse(saved);
      } catch (e) {
        console.warn('Failed to parse saved MCP context:', e);
      }
    }

    return {
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
  }

  private saveUserContext(): void {
    localStorage.setItem('mcpFlightContext', JSON.stringify(this.context));
  }

  public updateSearchHistory(search: FlightSearchParams): void {
    this.context.searchHistory.unshift(search);
    // Keep only last 10 searches
    this.context.searchHistory = this.context.searchHistory.slice(0, 10);
    this.saveUserContext();
  }

  public updatePreferredAirlines(airlines: string[]): void {
    this.context.preferredAirlines = [...new Set([...this.context.preferredAirlines, ...airlines])];
    this.saveUserContext();
  }

  public updateBudgetRange(min: number, max: number): void {
    this.context.budgetRange = { min, max };
    this.saveUserContext();
  }

  public addFrequentDestination(destination: string): void {
    if (!this.context.frequentDestinations.includes(destination)) {
      this.context.frequentDestinations.push(destination);
      this.saveUserContext();
    }
  }

  public updateUserPreferences(preferences: Partial<MCPFlightContext['userPreferences']>): void {
    this.context.userPreferences = { ...this.context.userPreferences, ...preferences };
    this.saveUserContext();
  }

  public buildFlightSearchContext(searchParams: FlightSearchParams): MCPContextData {
    return {
      protocol_version: "1.0",
      model: "flight-booking-assistant",
      timestamp: new Date().toISOString(),
      session_id: this.sessionId,
      system_context: {
        role: "AI Flight Booking Assistant",
        guidelines: [
          "Help users find the best flight options based on their preferences",
          "Provide accurate flight information and pricing",
          "Consider user's search history and preferences for personalized recommendations",
          "Suggest alternatives when exact matches aren't available",
          "Prioritize user safety and comfort"
        ],
        constraints: [
          "Only show real-time available flights",
          "Respect user's budget constraints",
          "Follow airline policies and regulations",
          "Ensure data privacy and security"
        ]
      },
      user_context: this.context,
      task_context: {
        task_type: "flight_search",
        specific_request: `Find flights from ${searchParams.from} to ${searchParams.to} on ${searchParams.departureDate}`,
        output_format: "structured_flight_results",
        constraints: {
          trip_type: searchParams.tripType,
          passengers: searchParams.passengers,
          class: searchParams.class,
          return_date: searchParams.returnDate
        }
      },
      document_context: {
        references: [
          {
            title: "User Search History",
            source: "user_profile",
            content: JSON.stringify(this.context.searchHistory.slice(0, 5))
          },
          {
            title: "User Preferences",
            source: "user_profile",
            content: JSON.stringify(this.context.userPreferences)
          }
        ]
      }
    };
  }

  public buildBookingContext(flight: Flight, passengers: number): MCPContextData {
    return {
      protocol_version: "1.0",
      model: "flight-booking-assistant",
      timestamp: new Date().toISOString(),
      session_id: this.sessionId,
      system_context: {
        role: "AI Flight Booking Assistant",
        guidelines: [
          "Guide users through the booking process step by step",
          "Ensure all required information is collected",
          "Verify booking details before confirmation",
          "Provide clear pricing breakdown",
          "Offer seat selection and additional services"
        ],
        constraints: [
          "Validate passenger information",
          "Secure payment processing",
          "Follow airline booking policies",
          "Provide booking confirmation details"
        ]
      },
      user_context: this.context,
      task_context: {
        task_type: "flight_booking",
        specific_request: `Book flight ${flight.flightNumber} for ${passengers} passenger(s)`,
        output_format: "booking_confirmation",
        constraints: {
          flight_id: flight.id,
          passengers: passengers,
          total_price: flight.price * passengers
        }
      },
      document_context: {
        references: [
          {
            title: "Selected Flight Details",
            source: "flight_data",
            content: JSON.stringify(flight)
          },
          {
            title: "User Booking History",
            source: "user_profile",
            content: "Previous booking preferences and patterns"
          }
        ]
      }
    };
  }

  public async getAIRecommendations(searchParams: FlightSearchParams): Promise<string[]> {
    const context = this.buildFlightSearchContext(searchParams);
    
    // Simulate AI recommendations based on context
    const recommendations: string[] = [];

    // Based on search history
    if (this.context.searchHistory.length > 0) {
      const frequentRoutes = this.context.searchHistory
        .filter(search => search.from === searchParams.from || search.to === searchParams.to)
        .slice(0, 3);
      
      if (frequentRoutes.length > 0) {
        recommendations.push("💡 Based on your search history, consider flexible dates for better prices");
      }
    }

    // Based on preferred airlines
    if (this.context.preferredAirlines.length > 0) {
      recommendations.push(`✈️ Your preferred airlines (${this.context.preferredAirlines.join(', ')}) have options on this route`);
    }

    // Based on budget
    if (searchParams.class === 'economy' && this.context.budgetRange.max > 1000) {
      recommendations.push("🎯 Consider premium economy for better comfort within your budget");
    }

    // Based on route patterns
    if (this.context.frequentDestinations.includes(searchParams.to)) {
      recommendations.push("🏆 This is one of your frequent destinations - check for loyalty program benefits");
    }

    return recommendations;
  }

  public async getSmartFilters(searchParams: FlightSearchParams): Promise<Record<string, any>> {
    const context = this.buildFlightSearchContext(searchParams);
    
    return {
      priceRange: {
        min: Math.max(0, this.context.budgetRange.min - 200),
        max: this.context.budgetRange.max + 200,
        suggested: [this.context.budgetRange.min, this.context.budgetRange.max]
      },
      preferredAirlines: this.context.preferredAirlines,
      stops: this.context.searchHistory.length > 0 
        ? this.getMostCommonStopPreference() 
        : 'any',
      departureTimePreferences: this.getTimePreferences()
    };
  }

  private getMostCommonStopPreference(): string {
    // Analyze search history to determine stop preferences
    return 'direct'; // Simplified for demo
  }

  private getTimePreferences(): string[] {
    // Analyze search patterns for time preferences
    return ['morning', 'afternoon']; // Simplified for demo
  }

  public getContext(): MCPFlightContext {
    return { ...this.context };
  }

  public resetSession(): void {
    this.sessionId = this.generateSessionId();
  }
}

export const mcpFlightClient = new MCPFlightClient();