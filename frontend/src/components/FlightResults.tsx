import React, { useState } from 'react';
import { Clock, Plane, MapPin, DollarSign, Users, Wifi, Utensils, Tv, Shield } from 'lucide-react';
import { format } from 'date-fns';
import type { Flight, FlightSearchResult } from '../types/flight';

interface FlightResultsProps {
  results: FlightSearchResult;
  loading?: boolean;
  onSelectFlight: (flight: Flight, isReturn?: boolean) => void;
  selectedOutbound?: Flight;
  selectedReturn?: Flight;
}

const FlightResults: React.FC<FlightResultsProps> = ({ 
  results, 
  loading = false, 
  onSelectFlight,
  selectedOutbound,
  selectedReturn 
}) => {
  const [activeTab, setActiveTab] = useState<'outbound' | 'return'>('outbound');
  const [sortBy, setSortBy] = useState<'price' | 'duration' | 'departure'>('price');
  const [filterBy, setFilterBy] = useState({
    maxPrice: 0,
    maxStops: 2,
    airlines: [] as string[]
  });

  if (loading) {
    return (
      <div className="bg-white rounded-2xl shadow-lg p-8">
        <div className="animate-pulse space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-32 bg-gray-200 rounded-lg"></div>
          ))}
        </div>
      </div>
    );
  }

  if (!results.outbound?.length) {
    return (
      <div className="bg-white rounded-2xl shadow-lg p-8 text-center">
        <Plane className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-900 mb-2">No flights found</h3>
        <p className="text-gray-600">Try adjusting your search criteria or dates</p>
      </div>
    );
  }

  const sortFlights = (flights: Flight[]) => {
    return [...flights].sort((a, b) => {
      switch (sortBy) {
        case 'price':
          return a.price - b.price;
        case 'duration':
          return parseInt(a.duration.replace('h', '')) - parseInt(b.duration.replace('h', ''));
        case 'departure':
          return new Date(a.departure.time).getTime() - new Date(b.departure.time).getTime();
        default:
          return 0;
      }
    });
  };

  const filterFlights = (flights: Flight[]) => {
    return flights.filter(flight => {
      if (filterBy.maxPrice && flight.price > filterBy.maxPrice) return false;
      if (flight.stops > filterBy.maxStops) return false;
      if (filterBy.airlines.length && !filterBy.airlines.includes(flight.airline)) return false;
      return true;
    });
  };

  const processFlights = (flights: Flight[]) => {
    return sortFlights(filterFlights(flights));
  };

  const formatTime = (timeString: string) => {
    return format(new Date(timeString), 'HH:mm');
  };

  const formatDate = (timeString: string) => {
    return format(new Date(timeString), 'MMM d');
  };

  const getStopsText = (stops: number) => {
    if (stops === 0) return 'Direct';
    if (stops === 1) return '1 Stop';
    return `${stops} Stops`;
  };

  const getAmenityIcon = (amenity: string) => {
    switch (amenity.toLowerCase()) {
      case 'wifi': return <Wifi className="w-4 h-4" />;
      case 'meal': case 'food': return <Utensils className="w-4 h-4" />;
      case 'entertainment': return <Tv className="w-4 h-4" />;
      case 'insurance': return <Shield className="w-4 h-4" />;
      default: return <span className="w-4 h-4 bg-blue-500 rounded-full"></span>;
    }
  };

  const FlightCard = ({ flight, isSelected, onSelect, type }: { 
    flight: Flight; 
    isSelected: boolean; 
    onSelect: () => void;
    type: 'outbound' | 'return';
  }) => (
    <div 
      className={`border rounded-xl p-6 transition-all duration-200 cursor-pointer hover:shadow-lg ${
        isSelected 
          ? 'border-primary-500 bg-primary-50 shadow-lg' 
          : 'border-gray-200 hover:border-gray-300'
      }`}
      onClick={onSelect}
    >
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-4">
          <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg flex items-center justify-center">
            <Plane className="w-6 h-6 text-white" />
          </div>
          <div>
            <h3 className="font-semibold text-lg text-gray-900">{flight.airline}</h3>
            <p className="text-sm text-gray-600">{flight.flightNumber} • {flight.aircraft}</p>
          </div>
        </div>
        <div className="text-right">
          <div className="text-2xl font-bold text-gray-900">${flight.price}</div>
          <div className="text-sm text-gray-600">{flight.currency}</div>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4 mb-4">
        {/* Departure */}
        <div className="text-center">
          <div className="text-2xl font-bold text-gray-900">{formatTime(flight.departure.time)}</div>
          <div className="text-sm text-gray-600">{flight.departure.airport.code}</div>
          <div className="text-xs text-gray-500">{formatDate(flight.departure.time)}</div>
          {flight.departure.terminal && (
            <div className="text-xs text-gray-500">Terminal {flight.departure.terminal}</div>
          )}
        </div>

        {/* Duration & Stops */}
        <div className="text-center">
          <div className="flex items-center justify-center mb-2">
            <div className="h-px bg-gray-300 flex-1"></div>
            <Clock className="w-4 h-4 text-gray-500 mx-2" />
            <div className="h-px bg-gray-300 flex-1"></div>
          </div>
          <div className="text-sm font-medium text-gray-900">{flight.duration}</div>
          <div className="text-xs text-gray-600">{getStopsText(flight.stops)}</div>
        </div>

        {/* Arrival */}
        <div className="text-center">
          <div className="text-2xl font-bold text-gray-900">{formatTime(flight.arrival.time)}</div>
          <div className="text-sm text-gray-600">{flight.arrival.airport.code}</div>
          <div className="text-xs text-gray-500">{formatDate(flight.arrival.time)}</div>
          {flight.arrival.terminal && (
            <div className="text-xs text-gray-500">Terminal {flight.arrival.terminal}</div>
          )}
        </div>
      </div>

      {/* Route */}
      <div className="flex items-center justify-center text-sm text-gray-600 mb-4">
        <MapPin className="w-4 h-4 mr-1" />
        {flight.departure.airport.city} → {flight.arrival.airport.city}
      </div>

      {/* Amenities */}
      {flight.amenities.length > 0 && (
        <div className="flex items-center justify-center gap-4 mb-4">
          {flight.amenities.slice(0, 4).map((amenity, index) => (
            <div key={index} className="flex items-center gap-1 text-xs text-gray-600">
              {getAmenityIcon(amenity)}
              <span className="capitalize">{amenity}</span>
            </div>
          ))}
          {flight.amenities.length > 4 && (
            <span className="text-xs text-gray-500">+{flight.amenities.length - 4} more</span>
          )}
        </div>
      )}

      {/* Class and Seats */}
      <div className="flex items-center justify-between text-sm">
        <div className="flex items-center gap-4">
          <span className="capitalize font-medium text-gray-900">{flight.class} Class</span>
          <div className="flex items-center gap-1 text-gray-600">
            <Users className="w-4 h-4" />
            {flight.availableSeats} seats left
          </div>
        </div>
        <button
          className={`px-4 py-2 rounded-lg font-medium transition-colors ${
            isSelected
              ? 'bg-primary-600 text-white'
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          }`}
          onClick={(e) => {
            e.stopPropagation();
            onSelect();
          }}
        >
          {isSelected ? 'Selected' : 'Select'}
        </button>
      </div>
    </div>
  );

  return (
    <div className="bg-white rounded-2xl shadow-lg">
      {/* Header with tabs */}
      <div className="border-b border-gray-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-bold text-gray-900">Flight Results</h2>
          <div className="flex items-center gap-4">
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value as typeof sortBy)}
              className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
            >
              <option value="price">Sort by Price</option>
              <option value="duration">Sort by Duration</option>
              <option value="departure">Sort by Departure</option>
            </select>
          </div>
        </div>

        {results.return && (
          <div className="flex gap-2">
            <button
              onClick={() => setActiveTab('outbound')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                activeTab === 'outbound'
                  ? 'bg-primary-600 text-white'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              Outbound ({results.outbound.length})
            </button>
            <button
              onClick={() => setActiveTab('return')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                activeTab === 'return'
                  ? 'bg-primary-600 text-white'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              Return ({results.return?.length || 0})
            </button>
          </div>
        )}
      </div>

      {/* Results */}
      <div className="p-6">
        <div className="space-y-4">
          {activeTab === 'outbound' ? (
            processFlights(results.outbound).map((flight) => (
              <FlightCard
                key={flight.id}
                flight={flight}
                isSelected={selectedOutbound?.id === flight.id}
                onSelect={() => onSelectFlight(flight, false)}
                type="outbound"
              />
            ))
          ) : (
            results.return && processFlights(results.return).map((flight) => (
              <FlightCard
                key={flight.id}
                flight={flight}
                isSelected={selectedReturn?.id === flight.id}
                onSelect={() => onSelectFlight(flight, true)}
                type="return"
              />
            ))
          )}
        </div>

        {/* Total Price */}
        {results.totalPrice && (selectedOutbound && (!results.return || selectedReturn)) && (
          <div className="mt-8 p-6 bg-green-50 border border-green-200 rounded-xl">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-lg font-semibold text-green-900">Total Trip Price</h3>
                <p className="text-sm text-green-700">
                  {selectedOutbound && `Outbound: $${selectedOutbound.price}`}
                  {selectedReturn && ` • Return: $${selectedReturn.price}`}
                </p>
              </div>
              <div className="text-right">
                <div className="text-3xl font-bold text-green-900">
                  ${(selectedOutbound?.price || 0) + (selectedReturn?.price || 0)}
                </div>
                <button className="mt-2 bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-6 rounded-lg transition-colors">
                  Continue to Booking
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default FlightResults;