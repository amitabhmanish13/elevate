import type { FlightSearchParams, FlightSearchResult, Flight, Airport } from '../types/flight';

// Mock data for demonstration
const mockAirports: Airport[] = [
  { code: 'JFK', name: 'John F. Kennedy International', city: 'New York', country: 'USA' },
  { code: 'LAX', name: 'Los Angeles International', city: 'Los Angeles', country: 'USA' },
  { code: 'LHR', name: 'Heathrow', city: 'London', country: 'UK' },
  { code: 'CDG', name: 'Charles de Gaulle', city: 'Paris', country: 'France' },
  { code: 'NRT', name: 'Narita International', city: 'Tokyo', country: 'Japan' },
  { code: 'DXB', name: 'Dubai International', city: 'Dubai', country: 'UAE' },
  { code: 'SIN', name: 'Singapore Changi', city: 'Singapore', country: 'Singapore' },
  { code: 'FRA', name: 'Frankfurt', city: 'Frankfurt', country: 'Germany' },
  { code: 'SYD', name: 'Sydney Kingsford Smith', city: 'Sydney', country: 'Australia' },
  { code: 'BOM', name: 'Chhatrapati Shivaji Maharaj International', city: 'Mumbai', country: 'India' }
];

const airlines = [
  'American Airlines', 'Delta Air Lines', 'United Airlines', 'British Airways',
  'Lufthansa', 'Emirates', 'Singapore Airlines', 'Air France', 'Qatar Airways',
  'Turkish Airlines', 'KLM', 'Swiss International Air Lines'
];

const aircraft = [
  'Boeing 737-800', 'Boeing 777-300ER', 'Airbus A320', 'Airbus A350-900',
  'Boeing 787-9', 'Airbus A380', 'Boeing 767-300', 'Airbus A330-300'
];

const amenities = [
  ['wifi', 'entertainment', 'meal'],
  ['wifi', 'meal'],
  ['entertainment', 'meal', 'insurance'],
  ['wifi', 'entertainment'],
  ['meal'],
  ['wifi', 'entertainment', 'meal', 'insurance']
];

function getRandomElement<T>(array: T[]): T {
  return array[Math.floor(Math.random() * array.length)];
}

function generateFlightId(): string {
  return `FL${Date.now()}${Math.random().toString(36).substr(2, 9)}`;
}

function generateFlightNumber(): string {
  const airline = getRandomElement(['AA', 'DL', 'UA', 'BA', 'LH', 'EK', 'SQ', 'AF', 'QR', 'TK']);
  const number = Math.floor(Math.random() * 9000) + 1000;
  return `${airline}${number}`;
}

function generateTime(baseDate: string, hourOffset: number = 0): string {
  const date = new Date(baseDate);
  date.setHours(Math.floor(Math.random() * 20) + 4 + hourOffset); // 4 AM to 11 PM
  date.setMinutes([0, 15, 30, 45][Math.floor(Math.random() * 4)]);
  return date.toISOString();
}

function calculateDuration(departureTime: string, arrivalTime: string): string {
  const departure = new Date(departureTime);
  const arrival = new Date(arrivalTime);
  const diff = arrival.getTime() - departure.getTime();
  const hours = Math.floor(diff / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  return `${hours}h ${minutes}m`;
}

function generatePrice(distance: number, flightClass: string, stops: number): number {
  let basePrice = 200 + (distance * 0.1);
  
  // Adjust for class
  switch (flightClass) {
    case 'business':
      basePrice *= 3;
      break;
    case 'first':
      basePrice *= 5;
      break;
    default:
      break;
  }
  
  // Adjust for stops
  basePrice *= (1 - (stops * 0.1));
  
  // Add some randomization
  basePrice *= (0.8 + Math.random() * 0.4);
  
  return Math.round(basePrice / 10) * 10; // Round to nearest 10
}

function getDistanceBetweenAirports(from: string, to: string): number {
  // Simplified distance calculation - in reality you'd use actual coordinates
  const routes: Record<string, Record<string, number>> = {
    'JFK': { 'LAX': 2445, 'LHR': 3470, 'CDG': 3635, 'NRT': 6740, 'DXB': 6840, 'SIN': 9520, 'BOM': 7800 },
    'LAX': { 'JFK': 2445, 'LHR': 5440, 'CDG': 5650, 'NRT': 5470, 'DXB': 8310, 'SIN': 8770, 'BOM': 8850 },
    'LHR': { 'JFK': 3470, 'LAX': 5440, 'CDG': 215, 'NRT': 5960, 'DXB': 3420, 'SIN': 6760, 'BOM': 4480 },
    // Add more as needed...
  };
  
  return routes[from]?.[to] || routes[to]?.[from] || 3000 + Math.random() * 5000;
}

function generateFlight(
  from: Airport,
  to: Airport,
  departureDate: string,
  flightClass: string,
  isReturn: boolean = false
): Flight {
  const stops = Math.random() > 0.7 ? (Math.random() > 0.8 ? 2 : 1) : 0;
  const departureTime = generateTime(departureDate);
  const flightDuration = 2 + (stops * 2) + Math.random() * 8; // 2-12 hours
  const arrivalTime = new Date(new Date(departureTime).getTime() + flightDuration * 60 * 60 * 1000).toISOString();
  const distance = getDistanceBetweenAirports(from.code, to.code);
  
  return {
    id: generateFlightId(),
    airline: getRandomElement(airlines),
    flightNumber: generateFlightNumber(),
    departure: {
      airport: from,
      time: departureTime,
      terminal: Math.random() > 0.5 ? ['1', '2', '3', 'A', 'B', 'C'][Math.floor(Math.random() * 6)] : undefined
    },
    arrival: {
      airport: to,
      time: arrivalTime,
      terminal: Math.random() > 0.5 ? ['1', '2', '3', 'A', 'B', 'C'][Math.floor(Math.random() * 6)] : undefined
    },
    duration: calculateDuration(departureTime, arrivalTime),
    price: generatePrice(distance, flightClass, stops),
    currency: 'USD',
    stops,
    aircraft: getRandomElement(aircraft),
    availableSeats: Math.floor(Math.random() * 50) + 10,
    class: flightClass as 'economy' | 'business' | 'first',
    amenities: getRandomElement(amenities)
  };
}

export class FlightApiService {
  private static delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  static async searchFlights(params: FlightSearchParams): Promise<FlightSearchResult> {
    // Simulate API delay
    await this.delay(1500 + Math.random() * 1000);

    const fromAirport = mockAirports.find(a => a.code === params.from);
    const toAirport = mockAirports.find(a => a.code === params.to);

    if (!fromAirport || !toAirport) {
      throw new Error('Invalid airport codes');
    }

    // Generate outbound flights
    const numOutboundFlights = 3 + Math.floor(Math.random() * 5); // 3-7 flights
    const outbound: Flight[] = [];
    
    for (let i = 0; i < numOutboundFlights; i++) {
      outbound.push(generateFlight(fromAirport, toAirport, params.departureDate, params.class));
    }

    // Generate return flights if round trip
    let returnFlights: Flight[] | undefined;
    if (params.tripType === 'roundTrip' && params.returnDate) {
      const numReturnFlights = 3 + Math.floor(Math.random() * 5);
      returnFlights = [];
      
      for (let i = 0; i < numReturnFlights; i++) {
        returnFlights.push(generateFlight(toAirport, fromAirport, params.returnDate, params.class, true));
      }
    }

    // Sort flights by price
    outbound.sort((a, b) => a.price - b.price);
    if (returnFlights) {
      returnFlights.sort((a, b) => a.price - b.price);
    }

    return {
      outbound,
      return: returnFlights,
      totalPrice: returnFlights 
        ? Math.min(...outbound.map(f => f.price)) + Math.min(...returnFlights.map(f => f.price))
        : Math.min(...outbound.map(f => f.price))
    };
  }

  static async getFlight(flightId: string): Promise<Flight | null> {
    await this.delay(500);
    
    // In a real implementation, this would fetch from a backend
    // For now, we'll return null as we don't store generated flights
    return null;
  }

  static async bookFlight(flightIds: string[], passengerInfo: any): Promise<{ bookingReference: string; status: string }> {
    await this.delay(2000);
    
    // Simulate booking process
    const bookingReference = `BK${Date.now().toString().slice(-6)}${Math.random().toString(36).substr(2, 3).toUpperCase()}`;
    
    // Simulate occasional booking failures for realism
    if (Math.random() < 0.05) {
      throw new Error('Booking failed: Selected flight is no longer available');
    }
    
    return {
      bookingReference,
      status: 'confirmed'
    };
  }

  static getPopularDestinations(): Airport[] {
    return mockAirports.slice(0, 6);
  }

  static searchAirports(query: string): Airport[] {
    return mockAirports.filter(airport =>
      airport.code.toLowerCase().includes(query.toLowerCase()) ||
      airport.city.toLowerCase().includes(query.toLowerCase()) ||
      airport.name.toLowerCase().includes(query.toLowerCase())
    );
  }
}