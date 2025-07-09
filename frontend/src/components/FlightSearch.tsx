import React, { useState, useEffect } from 'react';
import { Calendar, MapPin, Users, Plane, ArrowRightLeft, Search } from 'lucide-react';
import { format } from 'date-fns';
import type { FlightSearchParams, Airport } from '../types/flight';
import { mcpFlightClient } from '../services/mcpClient';

interface FlightSearchProps {
  onSearch: (params: FlightSearchParams) => void;
  loading?: boolean;
}

const popularAirports: Airport[] = [
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

const FlightSearch: React.FC<FlightSearchProps> = ({ onSearch, loading = false }) => {
  const [searchParams, setSearchParams] = useState<FlightSearchParams>({
    from: '',
    to: '',
    departureDate: format(new Date(), 'yyyy-MM-dd'),
    returnDate: undefined,
    passengers: 1,
    tripType: 'roundTrip',
    class: 'economy'
  });

  const [fromSuggestions, setFromSuggestions] = useState<Airport[]>([]);
  const [toSuggestions, setToSuggestions] = useState<Airport[]>([]);
  const [showFromSuggestions, setShowFromSuggestions] = useState(false);
  const [showToSuggestions, setShowToSuggestions] = useState(false);
  const [aiRecommendations, setAiRecommendations] = useState<string[]>([]);

  useEffect(() => {
    // Load AI recommendations when search params change
    const loadRecommendations = async () => {
      if (searchParams.from && searchParams.to) {
        try {
          const recommendations = await mcpFlightClient.getAIRecommendations(searchParams);
          setAiRecommendations(recommendations);
        } catch (error) {
          console.error('Failed to load AI recommendations:', error);
        }
      }
    };

    loadRecommendations();
  }, [searchParams.from, searchParams.to, searchParams.departureDate]);

  const handleFromChange = (value: string) => {
    setSearchParams(prev => ({ ...prev, from: value }));
    if (value.length > 0) {
      const filtered = popularAirports.filter(airport =>
        airport.code.toLowerCase().includes(value.toLowerCase()) ||
        airport.city.toLowerCase().includes(value.toLowerCase()) ||
        airport.name.toLowerCase().includes(value.toLowerCase())
      );
      setFromSuggestions(filtered);
      setShowFromSuggestions(true);
    } else {
      setShowFromSuggestions(false);
    }
  };

  const handleToChange = (value: string) => {
    setSearchParams(prev => ({ ...prev, to: value }));
    if (value.length > 0) {
      const filtered = popularAirports.filter(airport =>
        airport.code.toLowerCase().includes(value.toLowerCase()) ||
        airport.city.toLowerCase().includes(value.toLowerCase()) ||
        airport.name.toLowerCase().includes(value.toLowerCase())
      );
      setToSuggestions(filtered);
      setShowToSuggestions(true);
    } else {
      setShowToSuggestions(false);
    }
  };

  const selectAirport = (airport: Airport, field: 'from' | 'to') => {
    setSearchParams(prev => ({ ...prev, [field]: airport.code }));
    if (field === 'from') {
      setShowFromSuggestions(false);
      mcpFlightClient.addFrequentDestination(airport.code);
    } else {
      setShowToSuggestions(false);
      mcpFlightClient.addFrequentDestination(airport.code);
    }
  };

  const swapAirports = () => {
    setSearchParams(prev => ({
      ...prev,
      from: prev.to,
      to: prev.from
    }));
  };

  const handleTripTypeChange = (tripType: 'oneWay' | 'roundTrip') => {
    setSearchParams(prev => ({
      ...prev,
      tripType,
      returnDate: tripType === 'oneWay' ? undefined : prev.returnDate || format(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), 'yyyy-MM-dd')
    }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchParams.from && searchParams.to && searchParams.departureDate) {
      // Update MCP context with search history
      mcpFlightClient.updateSearchHistory(searchParams);
      onSearch(searchParams);
    }
  };

  const getAirportDisplay = (code: string) => {
    const airport = popularAirports.find(a => a.code === code);
    return airport ? `${airport.code} - ${airport.city}` : code;
  };

  return (
    <div className="bg-white rounded-2xl shadow-2xl p-8 max-w-6xl mx-auto">
      <div className="mb-8">
        <h1 className="text-4xl font-bold text-gray-900 mb-2">Find Your Perfect Flight</h1>
        <p className="text-gray-600">Powered by AI for personalized recommendations</p>
      </div>

      {/* Trip Type Selection */}
      <div className="flex gap-4 mb-6">
        <button
          type="button"
          onClick={() => handleTripTypeChange('roundTrip')}
          className={`px-6 py-3 rounded-lg font-medium transition-all duration-200 ${
            searchParams.tripType === 'roundTrip'
              ? 'bg-primary-600 text-white shadow-lg'
              : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          }`}
        >
          Round Trip
        </button>
        <button
          type="button"
          onClick={() => handleTripTypeChange('oneWay')}
          className={`px-6 py-3 rounded-lg font-medium transition-all duration-200 ${
            searchParams.tripType === 'oneWay'
              ? 'bg-primary-600 text-white shadow-lg'
              : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          }`}
        >
          One Way
        </button>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* From/To Section */}
        <div className="grid grid-cols-1 lg:grid-cols-5 gap-4 items-end">
          {/* From */}
          <div className="relative lg:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <MapPin className="inline w-4 h-4 mr-1" />
              From
            </label>
            <input
              type="text"
              value={searchParams.from ? getAirportDisplay(searchParams.from) : ''}
              onChange={(e) => handleFromChange(e.target.value)}
              placeholder="Enter city or airport"
              className="input-field"
              onFocus={() => setShowFromSuggestions(true)}
              onBlur={() => setTimeout(() => setShowFromSuggestions(false), 200)}
            />
            {showFromSuggestions && fromSuggestions.length > 0 && (
              <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                {fromSuggestions.map((airport) => (
                  <button
                    key={airport.code}
                    type="button"
                    onClick={() => selectAirport(airport, 'from')}
                    className="w-full px-4 py-3 text-left hover:bg-gray-50 focus:bg-gray-50 border-b border-gray-100 last:border-b-0"
                  >
                    <div className="font-medium">{airport.code} - {airport.city}</div>
                    <div className="text-sm text-gray-500">{airport.name}</div>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Swap Button */}
          <div className="flex justify-center lg:col-span-1">
            <button
              type="button"
              onClick={swapAirports}
              className="p-3 bg-gray-100 hover:bg-gray-200 rounded-full transition-colors duration-200"
              title="Swap airports"
            >
              <ArrowRightLeft className="w-5 h-5 text-gray-600" />
            </button>
          </div>

          {/* To */}
          <div className="relative lg:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <MapPin className="inline w-4 h-4 mr-1" />
              To
            </label>
            <input
              type="text"
              value={searchParams.to ? getAirportDisplay(searchParams.to) : ''}
              onChange={(e) => handleToChange(e.target.value)}
              placeholder="Enter city or airport"
              className="input-field"
              onFocus={() => setShowToSuggestions(true)}
              onBlur={() => setTimeout(() => setShowToSuggestions(false), 200)}
            />
            {showToSuggestions && toSuggestions.length > 0 && (
              <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                {toSuggestions.map((airport) => (
                  <button
                    key={airport.code}
                    type="button"
                    onClick={() => selectAirport(airport, 'to')}
                    className="w-full px-4 py-3 text-left hover:bg-gray-50 focus:bg-gray-50 border-b border-gray-100 last:border-b-0"
                  >
                    <div className="font-medium">{airport.code} - {airport.city}</div>
                    <div className="text-sm text-gray-500">{airport.name}</div>
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Dates and Passengers */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {/* Departure Date */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <Calendar className="inline w-4 h-4 mr-1" />
              Departure
            </label>
            <input
              type="date"
              value={searchParams.departureDate}
              onChange={(e) => setSearchParams(prev => ({ ...prev, departureDate: e.target.value }))}
              min={format(new Date(), 'yyyy-MM-dd')}
              className="input-field"
              required
            />
          </div>

          {/* Return Date */}
          {searchParams.tripType === 'roundTrip' && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Calendar className="inline w-4 h-4 mr-1" />
                Return
              </label>
              <input
                type="date"
                value={searchParams.returnDate || ''}
                onChange={(e) => setSearchParams(prev => ({ ...prev, returnDate: e.target.value }))}
                min={searchParams.departureDate}
                className="input-field"
                required
              />
            </div>
          )}

          {/* Passengers */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <Users className="inline w-4 h-4 mr-1" />
              Passengers
            </label>
            <select
              value={searchParams.passengers}
              onChange={(e) => setSearchParams(prev => ({ ...prev, passengers: parseInt(e.target.value) }))}
              className="select-field"
            >
              {[1, 2, 3, 4, 5, 6, 7, 8, 9].map(num => (
                <option key={num} value={num}>
                  {num} {num === 1 ? 'Passenger' : 'Passengers'}
                </option>
              ))}
            </select>
          </div>

          {/* Class */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <Plane className="inline w-4 h-4 mr-1" />
              Class
            </label>
            <select
              value={searchParams.class}
              onChange={(e) => setSearchParams(prev => ({ ...prev, class: e.target.value as 'economy' | 'business' | 'first' }))}
              className="select-field"
            >
              <option value="economy">Economy</option>
              <option value="business">Business</option>
              <option value="first">First Class</option>
            </select>
          </div>
        </div>

        {/* AI Recommendations */}
        {aiRecommendations.length > 0 && (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <h3 className="font-medium text-blue-900 mb-2">✨ AI Recommendations</h3>
            <ul className="space-y-1">
              {aiRecommendations.map((recommendation, index) => (
                <li key={index} className="text-sm text-blue-800">
                  {recommendation}
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Search Button */}
        <div className="flex justify-center">
          <button
            type="submit"
            disabled={loading || !searchParams.from || !searchParams.to || !searchParams.departureDate}
            className="btn-primary px-12 py-4 text-lg font-semibold rounded-xl shadow-lg disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-3"
          >
            {loading ? (
              <>
                <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent"></div>
                Searching Flights...
              </>
            ) : (
              <>
                <Search className="w-5 h-5" />
                Search Flights
              </>
            )}
          </button>
        </div>
      </form>
    </div>
  );
};

export default FlightSearch;