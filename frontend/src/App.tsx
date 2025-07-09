import React, { useState } from 'react';
import { Plane, Sparkles, Shield, Clock } from 'lucide-react';
import FlightSearch from './components/FlightSearch';
import FlightResults from './components/FlightResults';
import { FlightApiService } from './services/flightApi';
import { mcpFlightClient } from './services/mcpClient';
import type { FlightSearchParams, FlightSearchResult, Flight } from './types/flight';

function App() {
  const [currentView, setCurrentView] = useState<'search' | 'results'>('search');
  const [searchResults, setSearchResults] = useState<FlightSearchResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [selectedOutbound, setSelectedOutbound] = useState<Flight | null>(null);
  const [selectedReturn, setSelectedReturn] = useState<Flight | null>(null);
  const [searchParams, setSearchParams] = useState<FlightSearchParams | null>(null);

  const handleSearch = async (params: FlightSearchParams) => {
    setLoading(true);
    setSearchParams(params);
    
    try {
      // Update MCP context with search parameters
      mcpFlightClient.updateSearchHistory(params);
      
      // Perform search
      const results = await FlightApiService.searchFlights(params);
      setSearchResults(results);
      setCurrentView('results');
      setSelectedOutbound(null);
      setSelectedReturn(null);
    } catch (error) {
      console.error('Search failed:', error);
      alert('Search failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleSelectFlight = (flight: Flight, isReturn: boolean = false) => {
    if (isReturn) {
      setSelectedReturn(flight);
      // Update MCP context with airline preference
      mcpFlightClient.updatePreferredAirlines([flight.airline]);
    } else {
      setSelectedOutbound(flight);
      // Update MCP context with airline preference
      mcpFlightClient.updatePreferredAirlines([flight.airline]);
      
      // Add destination to frequent destinations
      mcpFlightClient.addFrequentDestination(flight.arrival.airport.code);
    }
  };

  const handleNewSearch = () => {
    setCurrentView('search');
    setSearchResults(null);
    setSelectedOutbound(null);
    setSelectedReturn(null);
    setSearchParams(null);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-indigo-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b border-gray-100">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg flex items-center justify-center">
                <Plane className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-900">FlightBooker</h1>
                <p className="text-xs text-gray-600">AI-Powered Flight Search</p>
              </div>
            </div>
            
            <div className="flex items-center space-x-6">
              <div className="hidden md:flex items-center space-x-4 text-sm text-gray-600">
                <div className="flex items-center space-x-1">
                  <Sparkles className="w-4 h-4 text-blue-500" />
                  <span>MCP Powered</span>
                </div>
                <div className="flex items-center space-x-1">
                  <Shield className="w-4 h-4 text-green-500" />
                  <span>Secure</span>
                </div>
                <div className="flex items-center space-x-1">
                  <Clock className="w-4 h-4 text-orange-500" />
                  <span>Real-time</span>
                </div>
              </div>
              
              {currentView === 'results' && (
                <button
                  onClick={handleNewSearch}
                  className="btn-secondary"
                >
                  New Search
                </button>
              )}
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {currentView === 'search' && (
          <>
            {/* Hero Section */}
            <div className="text-center mb-12">
              <h2 className="text-5xl font-bold text-gray-900 mb-4">
                Discover Your Next
                <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-purple-600"> Adventure</span>
              </h2>
              <p className="text-xl text-gray-600 max-w-3xl mx-auto mb-8">
                Experience the future of flight booking with AI-powered recommendations, 
                personalized search results, and seamless booking through our Model Context Protocol integration.
              </p>
              
              {/* Features */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto mb-12">
                <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-100">
                  <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                    <Sparkles className="w-6 h-6 text-blue-600" />
                  </div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">AI Recommendations</h3>
                  <p className="text-gray-600 text-sm">Get personalized flight suggestions based on your search history and preferences</p>
                </div>
                
                <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-100">
                  <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                    <Shield className="w-6 h-6 text-green-600" />
                  </div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">Secure Booking</h3>
                  <p className="text-gray-600 text-sm">Your data is protected with enterprise-grade security and encryption</p>
                </div>
                
                <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-100">
                  <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                    <Clock className="w-6 h-6 text-orange-600" />
                  </div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">Real-time Results</h3>
                  <p className="text-gray-600 text-sm">Access live flight data and pricing from multiple airlines worldwide</p>
                </div>
              </div>
            </div>

            {/* Search Form */}
            <FlightSearch onSearch={handleSearch} loading={loading} />

            {/* Popular Destinations */}
            <div className="mt-16">
              <h3 className="text-2xl font-bold text-gray-900 text-center mb-8">Popular Destinations</h3>
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
                {FlightApiService.getPopularDestinations().map((destination) => (
                  <div
                    key={destination.code}
                    className="bg-white rounded-xl p-4 shadow-lg border border-gray-100 hover:shadow-xl transition-shadow cursor-pointer group"
                  >
                    <div className="text-center">
                      <div className="text-2xl font-bold text-gray-900 mb-1">{destination.code}</div>
                      <div className="text-sm font-medium text-gray-700 mb-1">{destination.city}</div>
                      <div className="text-xs text-gray-500">{destination.country}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </>
        )}

        {currentView === 'results' && searchResults && (
          <>
            {/* Search Summary */}
            <div className="bg-white rounded-xl shadow-lg p-6 mb-8">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-2xl font-bold text-gray-900 mb-2">
                    {searchParams?.from} → {searchParams?.to}
                  </h2>
                  <p className="text-gray-600">
                    {searchParams?.passengers} {searchParams?.passengers === 1 ? 'passenger' : 'passengers'} • {searchParams?.class} class
                    {searchParams?.tripType === 'roundTrip' && ` • Round trip`}
                  </p>
                </div>
                <div className="text-right">
                  <div className="text-sm text-gray-600">Found {searchResults.outbound.length} flights</div>
                  {searchResults.return && (
                    <div className="text-sm text-gray-600">{searchResults.return.length} return flights</div>
                  )}
                </div>
              </div>
            </div>

            {/* Flight Results */}
            <FlightResults
              results={searchResults}
              loading={loading}
              onSelectFlight={handleSelectFlight}
              selectedOutbound={selectedOutbound || undefined}
              selectedReturn={selectedReturn || undefined}
            />
          </>
        )}
      </main>

      {/* Footer */}
      <footer className="bg-gray-900 text-white mt-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
            <div className="md:col-span-2">
              <div className="flex items-center space-x-3 mb-4">
                <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg flex items-center justify-center">
                  <Plane className="w-5 h-5 text-white" />
                </div>
                <span className="text-xl font-bold">FlightBooker</span>
              </div>
              <p className="text-gray-400 max-w-md">
                The world's first MCP-powered flight booking platform. Experience personalized 
                recommendations and seamless booking powered by advanced AI technology.
              </p>
            </div>
            
            <div>
              <h3 className="text-lg font-semibold mb-4">About</h3>
              <ul className="space-y-2 text-gray-400">
                <li>How it Works</li>
                <li>MCP Integration</li>
                <li>Privacy Policy</li>
                <li>Terms of Service</li>
              </ul>
            </div>
            
            <div>
              <h3 className="text-lg font-semibold mb-4">Support</h3>
              <ul className="space-y-2 text-gray-400">
                <li>Help Center</li>
                <li>Contact Us</li>
                <li>Flight Status</li>
                <li>Booking Management</li>
              </ul>
            </div>
          </div>
          
          <div className="border-t border-gray-800 mt-8 pt-8 text-center text-gray-400">
            <p>&copy; 2024 FlightBooker. Powered by Model Context Protocol. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;
