import React, { useState, useEffect } from 'react'
import { Activity, Network, Shield, Zap, Globe, Database } from 'lucide-react'

interface NetworkMetrics {
  ingressTraffic: number
  egressTraffic: number
  blockedConnections: number
  activeConnections: number
}

const NetworkDashboard: React.FC = () => {
  const [metrics, setMetrics] = useState<NetworkMetrics>({
    ingressTraffic: 0,
    egressTraffic: 0,
    blockedConnections: 0,
    activeConnections: 0
  })

  const [flowLogs, setFlowLogs] = useState<string[]>([])

  useEffect(() => {
    // Simulate real-time network metrics
    const interval = setInterval(() => {
      setMetrics(prev => ({
        ingressTraffic: prev.ingressTraffic + Math.floor(Math.random() * 50) + 10,
        egressTraffic: prev.egressTraffic + Math.floor(Math.random() * 30) + 5,
        blockedConnections: prev.blockedConnections + Math.floor(Math.random() * 3),
        activeConnections: Math.floor(Math.random() * 20) + 10
      }))

      // Simulate flow logs
      const newLog = `${new Date().toISOString()} | ${generateFlowLog()}`
      setFlowLogs(prev => [newLog, ...prev.slice(0, 9)]) // Keep last 10 logs
    }, 3000)

    return () => clearInterval(interval)
  }, [])

  const generateFlowLog = () => {
    const sources = ['frontend', 'backend', 'postgres', 'traffic-generator']
    const destinations = ['backend', 'postgres', 'external', 'frontend']
    const actions = ['ALLOWED', 'ALLOWED', 'ALLOWED', 'DENIED']
    
    const source = sources[Math.floor(Math.random() * sources.length)]
    const dest = destinations[Math.floor(Math.random() * destinations.length)]
    const action = actions[Math.floor(Math.random() * actions.length)]
    const port = [80, 443, 5432, 8080][Math.floor(Math.random() * 4)]
    
    return `${source} -> ${dest}:${port} ${action}`
  }

  const testConnectivity = async (type: string) => {
    try {
      await fetch(`/api/v1/demo/${type}`)
      const log = `${new Date().toISOString()} | Manual test: ${type} endpoint called`
      setFlowLogs(prev => [log, ...prev.slice(0, 9)])
    } catch (error) {
      console.error(`Failed to test ${type}:`, error)
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white rounded-lg shadow p-6">
        <div className="flex items-center space-x-3 mb-4">
          <Network className="h-8 w-8 text-purple-600" />
          <h2 className="text-2xl font-bold text-gray-900">Network Observability</h2>
        </div>
        <p className="text-gray-600">
          Real-time network traffic analysis powered by Cilium and Hubble
        </p>
      </div>

      {/* Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center">
            <div className="bg-blue-100 p-3 rounded-full">
              <Activity className="h-6 w-6 text-blue-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Ingress Traffic</p>
              <p className="text-2xl font-bold text-gray-900">{metrics.ingressTraffic}</p>
              <p className="text-xs text-gray-500">packets/min</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center">
            <div className="bg-green-100 p-3 rounded-full">
              <Globe className="h-6 w-6 text-green-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Egress Traffic</p>
              <p className="text-2xl font-bold text-gray-900">{metrics.egressTraffic}</p>
              <p className="text-xs text-gray-500">packets/min</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center">
            <div className="bg-red-100 p-3 rounded-full">
              <Shield className="h-6 w-6 text-red-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Blocked</p>
              <p className="text-2xl font-bold text-gray-900">{metrics.blockedConnections}</p>
              <p className="text-xs text-gray-500">connections</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center">
            <div className="bg-purple-100 p-3 rounded-full">
              <Zap className="h-6 w-6 text-purple-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Active</p>
              <p className="text-2xl font-bold text-gray-900">{metrics.activeConnections}</p>
              <p className="text-xs text-gray-500">connections</p>
            </div>
          </div>
        </div>
      </div>

      {/* Network Topology */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Network Topology</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Frontend */}
          <div className="text-center">
            <div className="bg-blue-100 p-4 rounded-full w-16 h-16 mx-auto mb-3 flex items-center justify-center">
              <Globe className="h-8 w-8 text-blue-600" />
            </div>
            <h4 className="font-semibold text-gray-900">Frontend</h4>
            <p className="text-sm text-gray-600">React App (Port 80)</p>
            <p className="text-xs text-green-600 mt-1">✓ 2 replicas</p>
          </div>

          {/* Backend */}
          <div className="text-center">
            <div className="bg-green-100 p-4 rounded-full w-16 h-16 mx-auto mb-3 flex items-center justify-center">
              <Activity className="h-8 w-8 text-green-600" />
            </div>
            <h4 className="font-semibold text-gray-900">Backend</h4>
            <p className="text-sm text-gray-600">Go API (Port 8080)</p>
            <p className="text-xs text-green-600 mt-1">✓ 2 replicas</p>
          </div>

          {/* Database */}
          <div className="text-center">
            <div className="bg-purple-100 p-4 rounded-full w-16 h-16 mx-auto mb-3 flex items-center justify-center">
              <Database className="h-8 w-8 text-purple-600" />
            </div>
            <h4 className="font-semibold text-gray-900">Database</h4>
            <p className="text-sm text-gray-600">PostgreSQL (Port 5432)</p>
            <p className="text-xs text-green-600 mt-1">✓ 1 replica</p>
          </div>
        </div>
      </div>

      {/* Connectivity Tests */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Connectivity Tests</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <button
            onClick={() => testConnectivity('slow')}
            className="p-4 bg-yellow-50 hover:bg-yellow-100 border border-yellow-200 rounded-lg transition-colors"
          >
            <div className="text-center">
              <Clock className="h-6 w-6 text-yellow-600 mx-auto mb-2" />
              <p className="font-medium text-yellow-900">Test Latency</p>
              <p className="text-xs text-yellow-700">Generate slow requests</p>
            </div>
          </button>

          <button
            onClick={() => testConnectivity('error')}
            className="p-4 bg-red-50 hover:bg-red-100 border border-red-200 rounded-lg transition-colors"
          >
            <div className="text-center">
              <X className="h-6 w-6 text-red-600 mx-auto mb-2" />
              <p className="font-medium text-red-900">Test Errors</p>
              <p className="text-xs text-red-700">Generate error responses</p>
            </div>
          </button>

          <button
            onClick={() => testConnectivity('external')}
            className="p-4 bg-blue-50 hover:bg-blue-100 border border-blue-200 rounded-lg transition-colors"
          >
            <div className="text-center">
              <Globe className="h-6 w-6 text-blue-600 mx-auto mb-2" />
              <p className="font-medium text-blue-900">Test External</p>
              <p className="text-xs text-blue-700">Call external services</p>
            </div>
          </button>
        </div>
      </div>

      {/* Flow Logs */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Recent Network Flows</h3>
        <div className="bg-gray-900 rounded-lg p-4 font-mono text-sm">
          {flowLogs.length === 0 ? (
            <p className="text-gray-400">Waiting for network flows...</p>
          ) : (
            flowLogs.map((log, index) => (
              <div
                key={index}
                className={`mb-1 ${
                  log.includes('DENIED') ? 'text-red-400' : 'text-green-400'
                }`}
              >
                {log}
              </div>
            ))
          )}
        </div>
      </div>

      {/* External Tools */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Observability Tools</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <a
            href="http://localhost:12000"
            target="_blank"
            rel="noopener noreferrer"
            className="block p-4 bg-blue-50 hover:bg-blue-100 border border-blue-200 rounded-lg transition-colors"
          >
            <div className="text-center">
              <Network className="h-8 w-8 text-blue-600 mx-auto mb-2" />
              <h4 className="font-semibold text-blue-900">Hubble UI</h4>
              <p className="text-sm text-blue-700">Network flow visualization</p>
            </div>
          </a>

          <a
            href="http://localhost:32003"
            target="_blank"
            rel="noopener noreferrer"
            className="block p-4 bg-orange-50 hover:bg-orange-100 border border-orange-200 rounded-lg transition-colors"
          >
            <div className="text-center">
              <Activity className="h-8 w-8 text-orange-600 mx-auto mb-2" />
              <h4 className="font-semibold text-orange-900">Grafana</h4>
              <p className="text-sm text-orange-700">Metrics dashboards</p>
            </div>
          </a>

          <a
            href="http://localhost:32002"
            target="_blank"
            rel="noopener noreferrer"
            className="block p-4 bg-red-50 hover:bg-red-100 border border-red-200 rounded-lg transition-colors"
          >
            <div className="text-center">
              <Database className="h-8 w-8 text-red-600 mx-auto mb-2" />
              <h4 className="font-semibold text-red-900">Prometheus</h4>
              <p className="text-sm text-red-700">Metrics collection</p>
            </div>
          </a>
        </div>
      </div>
    </div>
  )
}

export default NetworkDashboard