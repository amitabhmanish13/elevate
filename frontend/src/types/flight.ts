export interface Airport {
  code: string;
  name: string;
  city: string;
  country: string;
}

export interface FlightSearchParams {
  from: string;
  to: string;
  departureDate: string;
  returnDate?: string;
  passengers: number;
  tripType: 'oneWay' | 'roundTrip';
  class: 'economy' | 'business' | 'first';
}

export interface Flight {
  id: string;
  airline: string;
  flightNumber: string;
  departure: {
    airport: Airport;
    time: string;
    terminal?: string;
  };
  arrival: {
    airport: Airport;
    time: string;
    terminal?: string;
  };
  duration: string;
  price: number;
  currency: string;
  stops: number;
  aircraft: string;
  availableSeats: number;
  class: 'economy' | 'business' | 'first';
  amenities: string[];
}

export interface FlightSearchResult {
  outbound: Flight[];
  return?: Flight[];
  totalPrice?: number;
}

export interface Passenger {
  id: string;
  title: 'Mr' | 'Ms' | 'Mrs' | 'Dr';
  firstName: string;
  lastName: string;
  dateOfBirth: string;
  passportNumber?: string;
  nationality?: string;
  email: string;
  phone: string;
}

export interface BookingRequest {
  outboundFlight: Flight;
  returnFlight?: Flight;
  passengers: Passenger[];
  contactInfo: {
    email: string;
    phone: string;
  };
  paymentInfo: {
    method: 'card' | 'paypal' | 'bankTransfer';
    cardNumber?: string;
    expiryDate?: string;
    cvv?: string;
    holderName?: string;
  };
}

export interface Booking {
  id: string;
  bookingReference: string;
  status: 'confirmed' | 'pending' | 'cancelled';
  flights: Flight[];
  passengers: Passenger[];
  totalPrice: number;
  currency: string;
  bookedAt: string;
  contactInfo: {
    email: string;
    phone: string;
  };
}

export interface MCPFlightContext {
  searchHistory: FlightSearchParams[];
  preferredAirlines: string[];
  budgetRange: {
    min: number;
    max: number;
  };
  frequentDestinations: string[];
  userPreferences: {
    seatPreference: 'window' | 'aisle' | 'middle';
    mealPreference: string[];
    accessibilityNeeds: string[];
  };
}