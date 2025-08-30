package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	_ "github.com/lib/pq"
)

var (
	// Prometheus metrics
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)
	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "http_request_duration_seconds",
			Help: "Duration of HTTP requests",
		},
		[]string{"method", "endpoint"},
	)
	dbConnectionsActive = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "db_connections_active",
			Help: "Number of active database connections",
		},
	)
)

type User struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

type Task struct {
	ID          int    `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	UserID      int    `json:"user_id"`
	Completed   bool   `json:"completed"`
	CreatedAt   string `json:"created_at"`
}

var db *sql.DB

func init() {
	// Register Prometheus metrics
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
	prometheus.MustRegister(dbConnectionsActive)
}

func initDB() {
	var err error
	dbHost := getEnv("DB_HOST", "postgres")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "demo")
	dbPassword := getEnv("DB_PASSWORD", "demo123")
	dbName := getEnv("DB_NAME", "demodb")

	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword, dbName)

	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	// Test connection
	if err = db.Ping(); err != nil {
		log.Fatal("Failed to ping database:", err)
	}

	// Update connection metrics
	stats := db.Stats()
	dbConnectionsActive.Set(float64(stats.OpenConnections))

	log.Println("✅ Database connected successfully")
}

func getEnv(key, defaultVal string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultVal
}

func prometheusMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		
		c.Next()
		
		duration := time.Since(start).Seconds()
		status := strconv.Itoa(c.Writer.Status())
		
		httpRequestsTotal.WithLabelValues(c.Request.Method, c.FullPath(), status).Inc()
		httpRequestDuration.WithLabelValues(c.Request.Method, c.FullPath()).Observe(duration)
	}
}

func main() {
	// Initialize database
	initDB()
	defer db.Close()

	// Set up Gin router
	r := gin.Default()

	// Add CORS middleware
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"*"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	// Add Prometheus middleware
	r.Use(prometheusMiddleware())

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy", "timestamp": time.Now().Unix()})
	})

	// Metrics endpoint
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// API routes
	api := r.Group("/api/v1")
	{
		// Users endpoints
		api.GET("/users", getUsers)
		api.POST("/users", createUser)
		api.GET("/users/:id", getUser)

		// Tasks endpoints
		api.GET("/tasks", getTasks)
		api.POST("/tasks", createTask)
		api.PUT("/tasks/:id", updateTask)
		api.DELETE("/tasks/:id", deleteTask)

		// Demo endpoints for generating traffic
		api.GET("/demo/slow", slowEndpoint)
		api.GET("/demo/error", errorEndpoint)
		api.GET("/demo/external", externalCallEndpoint)
	}

	port := getEnv("PORT", "8080")
	log.Printf("🚀 Server starting on port %s", port)
	r.Run(":" + port)
}

func getUsers(c *gin.Context) {
	rows, err := db.Query("SELECT id, name, email FROM users ORDER BY id")
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var user User
		if err := rows.Scan(&user.ID, &user.Name, &user.Email); err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		users = append(users, user)
	}

	c.JSON(200, users)
}

func createUser(c *gin.Context) {
	var user User
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	err := db.QueryRow("INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id",
		user.Name, user.Email).Scan(&user.ID)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(201, user)
}

func getUser(c *gin.Context) {
	id := c.Param("id")
	var user User
	err := db.QueryRow("SELECT id, name, email FROM users WHERE id = $1", id).
		Scan(&user.ID, &user.Name, &user.Email)
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(404, gin.H{"error": "User not found"})
		} else {
			c.JSON(500, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(200, user)
}

func getTasks(c *gin.Context) {
	userID := c.Query("user_id")
	var rows *sql.Rows
	var err error

	if userID != "" {
		rows, err = db.Query("SELECT id, title, description, user_id, completed, created_at FROM tasks WHERE user_id = $1 ORDER BY created_at DESC", userID)
	} else {
		rows, err = db.Query("SELECT id, title, description, user_id, completed, created_at FROM tasks ORDER BY created_at DESC")
	}

	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	var tasks []Task
	for rows.Next() {
		var task Task
		var createdAt time.Time
		if err := rows.Scan(&task.ID, &task.Title, &task.Description, &task.UserID, &task.Completed, &createdAt); err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		task.CreatedAt = createdAt.Format(time.RFC3339)
		tasks = append(tasks, task)
	}

	c.JSON(200, tasks)
}

func createTask(c *gin.Context) {
	var task Task
	if err := c.ShouldBindJSON(&task); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	var createdAt time.Time
	err := db.QueryRow("INSERT INTO tasks (title, description, user_id, completed) VALUES ($1, $2, $3, $4) RETURNING id, created_at",
		task.Title, task.Description, task.UserID, task.Completed).Scan(&task.ID, &createdAt)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	task.CreatedAt = createdAt.Format(time.RFC3339)
	c.JSON(201, task)
}

func updateTask(c *gin.Context) {
	id := c.Param("id")
	var task Task
	if err := c.ShouldBindJSON(&task); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	_, err := db.Exec("UPDATE tasks SET title = $1, description = $2, completed = $3 WHERE id = $4",
		task.Title, task.Description, task.Completed, id)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Task updated successfully"})
}

func deleteTask(c *gin.Context) {
	id := c.Param("id")
	_, err := db.Exec("DELETE FROM tasks WHERE id = $1", id)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Task deleted successfully"})
}

// Demo endpoints for generating traffic and demonstrating network policies
func slowEndpoint(c *gin.Context) {
	time.Sleep(2 * time.Second)
	c.JSON(200, gin.H{"message": "This was a slow endpoint", "duration": "2s"})
}

func errorEndpoint(c *gin.Context) {
	c.JSON(500, gin.H{"error": "This is a demo error endpoint"})
}

func externalCallEndpoint(c *gin.Context) {
	// Simulate external API call
	resp, err := http.Get("https://httpbin.org/json")
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to call external service"})
		return
	}
	defer resp.Body.Close()

	c.JSON(200, gin.H{"message": "External call successful", "status": resp.Status})
} 