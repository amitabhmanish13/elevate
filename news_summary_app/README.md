# 🤖 AI News Summary App

Automatically collect and summarize the top 10 AI tech news daily from leading technology sources and receive them via email.

## ✨ Features

- **Smart AI News Collection**: Fetches from 8+ top tech news sources including TechCrunch, MIT Technology Review, The Verge, Wired, and more
- **Intelligent Filtering**: Uses keyword matching and content analysis to identify AI-related articles
- **Advanced Ranking**: Scores articles based on recency, source quality, AI relevance, and engagement potential
- **Beautiful Email Summaries**: Sends HTML-formatted emails with article summaries, scores, and direct links
- **AI-Powered Summaries**: Optional OpenAI integration for enhanced article summaries
- **Flexible Scheduling**: Run once, test components, or schedule daily delivery
- **Comprehensive Logging**: Track performance and troubleshoot issues

## 📰 News Sources

- **TechCrunch AI** - AI-focused tech news
- **MIT Technology Review** - Research and innovation
- **Ars Technica** - Deep technical coverage
- **The Verge** - Consumer technology
- **Wired** - Technology and culture
- **AI News** - Dedicated AI coverage
- **VentureBeat AI** - AI business news
- **IEEE Spectrum** - Engineering and research

## 🚀 Quick Start

### Prerequisites

- Python 3.8 or higher
- Gmail account with App Password enabled (for sending emails)
- Optional: OpenAI API key for enhanced summaries

### Installation

1. **Clone or download the application**:
```bash
cd news_summary_app/
```

2. **Install dependencies**:
```bash
pip install -r requirements.txt
```

3. **Configure environment variables**:
```bash
cp .env.example .env
# Edit .env with your email settings
```

4. **Test the setup**:
```bash
python main.py test
```

5. **Send a test email**:
```bash
python main.py test-email
```

### Email Setup (Gmail)

1. **Enable 2-Factor Authentication** on your Gmail account
2. **Generate an App Password**:
   - Go to Google Account settings → Security
   - Enable 2-Factor Authentication
   - Go to App Passwords
   - Generate a password for "Mail"
3. **Update .env file**:
```env
EMAIL_SENDER=your_email@gmail.com
EMAIL_PASSWORD=your_16_character_app_password
EMAIL_RECIPIENT=amitabhmanish13@gmail.com
```

## 📋 Usage

### Run Once
```bash
python main.py run-once
```

### Schedule Daily Delivery
```bash
python main.py schedule
```
This will run continuously and send daily summaries at the configured time (default: 9:00 AM).

### Test Components
```bash
python main.py test
```

### Send Test Email
```bash
python main.py test-email
```

## ⚙️ Configuration

### Environment Variables (.env)

```env
# Email Configuration
EMAIL_SENDER=your_email@gmail.com
EMAIL_PASSWORD=your_app_password
EMAIL_RECIPIENT=amitabhmanish13@gmail.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587

# Optional: OpenAI API Key for AI-powered summaries
OPENAI_API_KEY=your_openai_api_key_here

# News Configuration
MAX_NEWS_ITEMS=10
SUMMARY_LENGTH=short

# Scheduling
SEND_TIME=09:00
```

### Customization Options

- **MAX_NEWS_ITEMS**: Number of articles to include (default: 10)
- **SEND_TIME**: Daily delivery time in HH:MM format (default: 09:00)
- **OPENAI_API_KEY**: Enable AI-powered summaries (optional)

## 🔧 Running as a Service

### Linux/macOS (systemd)

1. **Create service file**:
```bash
sudo nano /etc/systemd/system/ai-news-summary.service
```

2. **Add service configuration**:
```ini
[Unit]
Description=AI News Summary Service
After=network.target

[Service]
Type=simple
User=your_username
WorkingDirectory=/path/to/news_summary_app
ExecStart=/usr/bin/python3 /path/to/news_summary_app/main.py schedule
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

3. **Enable and start service**:
```bash
sudo systemctl enable ai-news-summary.service
sudo systemctl start ai-news-summary.service
```

### Docker

1. **Create Dockerfile**:
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["python", "main.py", "schedule"]
```

2. **Build and run**:
```bash
docker build -t ai-news-summary .
docker run -d --env-file .env ai-news-summary
```

## 📊 Article Scoring

Articles are scored (0-10) based on:

- **Recency (30%)**: How recently published
- **Source Quality (20%)**: Reputation of news source
- **AI Relevance (30%)**: AI-related keywords and content
- **Engagement (20%)**: Title and content appeal

## 🎯 Filtering Criteria

### AI Keywords
- artificial intelligence, ai, machine learning, ml, deep learning
- neural network, chatgpt, openai, anthropic, claude, gpt
- llm, large language model, automation, robotics
- computer vision, natural language processing, nlp
- generative ai, ai model

### High-Value Keywords (Bonus Points)
- breakthrough, announcement, release, launch, funding
- acquisition, research, development, innovation
- chatgpt, openai, anthropic, google ai, microsoft ai
- nvidia, tesla, autonomous, robotics

## 📈 Monitoring and Logs

- **Log file**: `news_summary.log`
- **Log levels**: INFO, WARNING, ERROR
- **Statistics**: Article counts, scores, sources covered

### Sample Log Output
```
2024-01-15 09:00:01 - INFO - Starting daily AI news summary process...
2024-01-15 09:00:02 - INFO - Fetching news from TechCrunch AI
2024-01-15 09:00:15 - INFO - Collected 45 articles
2024-01-15 09:00:16 - INFO - Selected top 10 articles
2024-01-15 09:00:18 - INFO - Email sent successfully to amitabhmanish13@gmail.com
2024-01-15 09:00:18 - INFO - Summary stats - Articles: 10, Avg Score: 7.2, Sources: 6
```

## 🔍 Troubleshooting

### Common Issues

1. **Email Authentication Error**:
   - Ensure 2FA is enabled on Gmail
   - Use App Password, not regular password
   - Check EMAIL_SENDER and EMAIL_PASSWORD in .env

2. **No Articles Found**:
   - Check internet connection
   - RSS feeds may be temporarily unavailable
   - Try running during peak news hours

3. **OpenAI API Errors**:
   - Verify API key is correct
   - Check API usage limits
   - App works without OpenAI (uses basic summaries)

4. **Permission Denied**:
   - Ensure Python file has execute permissions
   - Check file paths in service configuration

### Debug Mode
```bash
# Run with detailed logging
python -u main.py run-once 2>&1 | tee debug.log
```

## 📧 Email Sample

The emails include:
- **Header**: Date and summary count
- **Article List**: Title, source, score, summary, and link
- **Statistics**: Total articles, average score, sources covered
- **HTML Formatting**: Beautiful, mobile-responsive design

## 🔒 Security Considerations

- Store sensitive credentials in `.env` file
- Use App Passwords for Gmail (never regular passwords)
- Keep OpenAI API keys secure
- Run with appropriate user permissions
- Regularly update dependencies

## 🤝 Contributing

Feel free to:
- Add new news sources
- Improve filtering algorithms
- Enhance email templates
- Add new output formats

## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section
2. Review log files
3. Test individual components
4. Verify environment configuration

---

**🤖 Built with ❤️ for staying updated on AI developments**