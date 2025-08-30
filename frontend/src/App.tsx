import React, { useState, useEffect } from 'react'
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom'
import { Users, CheckSquare, Activity, Network, Eye } from 'lucide-react'
import UsersPage from './components/UsersPage'
import TasksPage from './components/TasksPage'
import NetworkDashboard from './components/NetworkDashboard'
import './App.css'

interface AppStats {
  totalUsers: number
  totalTasks: number
  completedTasks: number
  systemHealth: string
}

function App() {
  const [stats, setStats] = useState<AppStats>({
    totalUsers: 0,
    totalTasks: 0,
    completedTasks: 0,
    systemHealth: 'unknown'
  })

  useEffect(() => {
    fetchStats()
    const interval = setInterval(fetchStats, 30000) // Update every 30 seconds
    return () => clearInterval(interval)
  }, [])

  const fetchStats = async () => {
    try {
      const [usersRes, tasksRes, healthRes] = await Promise.all([
        fetch('/api/v1/users'),
        fetch('/api/v1/tasks'),
        fetch('/health')
      ])

      const users = await usersRes.json()
      const tasks = await tasksRes.json()
      const health = await healthRes.json()

      setStats({
        totalUsers: users.length || 0,
        totalTasks: tasks.length || 0,
        completedTasks: tasks.filter((t: any) => t.completed).length || 0,
        systemHealth: health.status || 'unknown'
      })
    } catch (error) {
      console.error('Failed to fetch stats:', error)
      setStats(prev => ({ ...prev, systemHealth: 'error' }))
    }
  }

  return (
    <Router>
      <div className="min-h-screen bg-gray-100">
        {/* Navigation */}
        <nav className="bg-blue-600 text-white shadow-lg">
          <div className="max-w-7xl mx-auto px-4">
            <div className="flex justify-between items-center h-16">
              <div className="flex items-center space-x-4">
                <Network className="h-8 w-8" />
                <h1 className="text-xl font-bold">Cilium Network Demo</h1>
              </div>
              <div className="flex space-x-6">
                <Link to="/" className="flex items-center space-x-1 hover:text-blue-200">
                  <Activity className="h-4 w-4" />
                  <span>Dashboard</span>
                </Link>
                <Link to="/users" className="flex items-center space-x-1 hover:text-blue-200">
                  <Users className="h-4 w-4" />
                  <span>Users</span>
                </Link>
                <Link to="/tasks" className="flex items-center space-x-1 hover:text-blue-200">
                  <CheckSquare className="h-4 w-4" />
                  <span>Tasks</span>
                </Link>
                <Link to="/network" className="flex items-center space-x-1 hover:text-blue-200">
                  <Eye className="h-4 w-4" />
                  <span>Network</span>
                </Link>
              </div>
            </div>
          </div>
        </nav>

        {/* Main Content */}
        <main className="max-w-7xl mx-auto py-6 px-4">
          <Routes>
            <Route path="/" element={<Dashboard stats={stats} />} />
            <Route path="/users" element={<UsersPage />} />
            <Route path="/tasks" element={<TasksPage />} />
            <Route path="/network" element={<NetworkDashboard />} />
          </Routes>
        </main>
      </div>
    </Router>
  )
}

function Dashboard({ stats }: { stats: AppStats }) {
  const [networkTraffic, setNetworkTraffic] = useState(0)

  useEffect(() => {
    const interval = setInterval(() => {
      setNetworkTraffic(prev => prev + Math.floor(Math.random() * 10) + 1)
    }, 2000)
    return () => clearInterval(interval)
  }, [])

  const generateTraffic = async (type: string) => {
    try {
      const endpoint = `/api/v1/demo/${type}`
      await fetch(endpoint)
    } catch (error) {
      console.error(`Failed to generate ${type} traffic:`, error)
    }
  }

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">
          Cilium Network Observability Demo
        </h2>
        <p className="text-gray-600 mb-6">
          This demo showcases Cilium CNI with Hubble for network visibility, 
          integrated with Prometheus and Grafana monitoring.
        </p>
        
        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
            <div className="flex items-center">
              <Users className="h-8 w-8 text-blue-600" />
              <div className="ml-3">
                <p className="text-sm font-medium text-blue-600">Total Users</p>
                <p className="text-2xl font-bold text-blue-900">{stats.totalUsers}</p>
              </div>
            </div>
          </div>
          
          <div className="bg-green-50 p-4 rounded-lg border border-green-200">
            <div className="flex items-center">
              <CheckSquare className="h-8 w-8 text-green-600" />
              <div className="ml-3">
                <p className="text-sm font-medium text-green-600">Completed Tasks</p>
                <p className="text-2xl font-bold text-green-900">{stats.completedTasks}/{stats.totalTasks}</p>
              </div>
            </div>
          </div>
          
          <div className="bg-purple-50 p-4 rounded-lg border border-purple-200">
            <div className="flex items-center">
              <Activity className="h-8 w-8 text-purple-600" />
              <div className="ml-3">
                <p className="text-sm font-medium text-purple-600">System Health</p>
                <p className="text-2xl font-bold text-purple-900 capitalize">{stats.systemHealth}</p>
              </div>
            </div>
          </div>
          
          <div className="bg-orange-50 p-4 rounded-lg border border-orange-200">
            <div className="flex items-center">
              <Network className="h-8 w-8 text-orange-600" />
              <div className="ml-3">
                <p className="text-sm font-medium text-orange-600">Network Events</p>
                <p className="text-2xl font-bold text-orange-900">{networkTraffic}</p>
              </div>
            </div>
          </div>
        </div>

        {/* Traffic Generation Controls */}
        <div className="bg-gray-50 p-6 rounded-lg">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Generate Demo Traffic
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <button
              onClick={() => generateTraffic('slow')}
              className="bg-yellow-500 hover:bg-yellow-600 text-white px-4 py-2 rounded-lg transition-colors"
            >
              Generate Slow Requests
            </button>
            <button
              onClick={() => generateTraffic('error')}
              className="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg transition-colors"
            >
              Generate Error Traffic
            </button>
            <button
              onClick={() => generateTraffic('external')}
              className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg transition-colors"
            >
              Generate External Calls
            </button>
          </div>
        </div>

        {/* Quick Links */}
        <div className="mt-6 bg-white border rounded-lg p-4">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Observability Tools
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <a
              href="http://localhost:12000"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center space-x-2 p-3 bg-blue-50 hover:bg-blue-100 rounded-lg transition-colors"
            >
              <Eye className="h-5 w-5 text-blue-600" />
              <span className="text-blue-900 font-medium">Hubble UI</span>
            </a>
            <a
              href="http://localhost:32003"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center space-x-2 p-3 bg-orange-50 hover:bg-orange-100 rounded-lg transition-colors"
            >
              <Activity className="h-5 w-5 text-orange-600" />
              <span className="text-orange-900 font-medium">Grafana</span>
            </a>
            <a
              href="http://localhost:32002"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center space-x-2 p-3 bg-red-50 hover:bg-red-100 rounded-lg transition-colors"
            >
              <Activity className="h-5 w-5 text-red-600" />
              <span className="text-red-900 font-medium">Prometheus</span>
            </a>
          </div>
        </div>
      </div>
    </div>
  )
}

export default App
