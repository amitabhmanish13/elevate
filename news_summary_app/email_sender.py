import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
from typing import List, Dict
import logging
from datetime import datetime

class EmailSender:
    def __init__(self):
        self.smtp_server = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
        self.smtp_port = int(os.getenv('SMTP_PORT', '587'))
        self.sender_email = os.getenv('EMAIL_SENDER')
        self.sender_password = os.getenv('EMAIL_PASSWORD')
        self.recipient_email = os.getenv('EMAIL_RECIPIENT', 'amitabhmanish13@gmail.com')
        
        if not self.sender_email or not self.sender_password:
            raise ValueError("EMAIL_SENDER and EMAIL_PASSWORD must be set in environment variables")

    def convert_markdown_to_html(self, markdown_content: str) -> str:
        """Convert basic markdown formatting to HTML."""
        html_content = markdown_content
        
        # Convert headers
        html_content = html_content.replace('**', '<strong>').replace('**', '</strong>')
        
        # Convert line breaks
        html_content = html_content.replace('\n\n', '</p><p>')
        html_content = html_content.replace('\n', '<br>')
        
        # Wrap in paragraphs
        html_content = f'<p>{html_content}</p>'
        
        # Fix double paragraph tags
        html_content = html_content.replace('<p></p>', '')
        
        return html_content

    def create_html_email_template(self, content: str) -> str:
        """Create a beautiful HTML email template."""
        html_content = self.convert_markdown_to_html(content)
        
        html_template = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI Tech News Summary</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }}
        .container {{
            background-color: white;
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }}
        .header {{
            text-align: center;
            border-bottom: 3px solid #007bff;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }}
        .header h1 {{
            color: #007bff;
            margin: 0;
            font-size: 28px;
        }}
        .news-item {{
            border-left: 4px solid #28a745;
            padding-left: 20px;
            margin: 25px 0;
            background-color: #f8f9fa;
            border-radius: 0 8px 8px 0;
            padding: 20px;
        }}
        .news-title {{
            color: #1e40af;
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 10px;
            text-decoration: none;
        }}
        .news-meta {{
            color: #6b7280;
            font-size: 14px;
            margin-bottom: 12px;
        }}
        .news-summary {{
            margin-bottom: 15px;
            line-height: 1.6;
        }}
        .news-link {{
            display: inline-block;
            background-color: #007bff;
            color: white;
            padding: 8px 16px;
            border-radius: 6px;
            text-decoration: none;
            font-size: 14px;
            margin-top: 10px;
        }}
        .news-link:hover {{
            background-color: #0056b3;
        }}
        .stats {{
            background-color: #e3f2fd;
            border-radius: 8px;
            padding: 20px;
            margin-top: 30px;
            border-left: 4px solid #2196f3;
        }}
        .footer {{
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: 14px;
        }}
        .emoji {{
            font-size: 1.2em;
            margin-right: 8px;
        }}
        hr {{
            border: none;
            height: 2px;
            background: linear-gradient(to right, #007bff, #28a745, #ffc107);
            margin: 25px 0;
            border-radius: 2px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 AI Tech News Summary</h1>
            <p style="color: #6b7280; margin: 10px 0 0 0;">{datetime.now().strftime('%A, %B %d, %Y')}</p>
        </div>
        
        {html_content}
        
        <div class="footer">
            <p>📧 Delivered to your inbox with ❤️ by AI News Summary Bot</p>
            <p>🔔 This is an automated summary of the latest AI and technology news</p>
        </div>
    </div>
</body>
</html>
"""
        return html_template

    def send_email(self, subject: str, content: str, is_html: bool = True) -> bool:
        """Send email with the news summary."""
        try:
            # Create message
            message = MIMEMultipart("alternative")
            message["From"] = self.sender_email
            message["To"] = self.recipient_email
            message["Subject"] = subject
            
            # Create HTML and text versions
            if is_html:
                html_content = self.create_html_email_template(content)
                html_part = MIMEText(html_content, "html")
                message.attach(html_part)
                
                # Also include plain text version
                text_part = MIMEText(content, "plain")
                message.attach(text_part)
            else:
                text_part = MIMEText(content, "plain")
                message.attach(text_part)
            
            # Connect to server and send email
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()  # Enable security
                server.login(self.sender_email, self.sender_password)
                server.send_message(message)
            
            logging.info(f"Email sent successfully to {self.recipient_email}")
            return True
            
        except Exception as e:
            logging.error(f"Failed to send email: {e}")
            return False

    def send_news_summary(self, articles: List[Dict]) -> bool:
        """Send the daily news summary email."""
        if not articles:
            subject = f"🤖 AI Tech News Summary - {datetime.now().strftime('%B %d, %Y')} - No News Today"
            content = """
🤖 **AI Tech News Summary**

📅 **{date}**

Unfortunately, no significant AI news was found today from our monitored sources. 

This could mean:
• It's a slow news day in the AI world
• Our sources haven't published new content yet
• Technical issues with news collection

We'll be back tomorrow with the latest AI developments!

🤖 Generated by AI News Summary Bot
""".format(date=datetime.now().strftime('%B %d, %Y'))
        else:
            subject = f"🤖 Top {len(articles)} AI Tech News - {datetime.now().strftime('%B %d, %Y')}"
            
            # Format content for email
            content = f"""
🤖 **Top {len(articles)} AI Tech News - {datetime.now().strftime('%B %d, %Y')}**

"""
            
            for i, article in enumerate(articles, 1):
                score_emoji = "🌟" if article['score'] > 8 else "⭐" if article['score'] > 6 else "✨"
                content += f"""
<div class="news-item">
📰 **{i}. {article['title']}**

<div class="news-meta">
🏢 **Source:** {article['source']} | {score_emoji} **Score:** {article['score']:.1f}/10 | 📅 **Published:** {article['published'].strftime('%H:%M, %B %d')}
</div>

<div class="news-summary">
{article.get('ai_summary', article['summary'])}
</div>

<a href="{article['url']}" class="news-link">Read Full Article →</a>
</div>

<hr>

"""
            
            # Add summary statistics
            avg_score = sum(a['score'] for a in articles) / len(articles)
            sources_count = len(set(a['source'] for a in articles))
            
            content += f"""
<div class="stats">
📊 **Summary Statistics:**

• **Total articles:** {len(articles)}
• **Average relevance score:** {avg_score:.1f}/10
• **Sources covered:** {sources_count}
• **Time range:** Last 24 hours
</div>

---

🤖 **About This Summary:**
This email was automatically generated by analyzing tech news from {sources_count} top sources, filtering for AI-related content, and ranking by relevance, recency, and source quality.

📬 **Questions or feedback?** This is an automated service.
"""
        
        return self.send_email(subject, content, is_html=True)

    def test_email_connection(self) -> bool:
        """Test the email configuration."""
        try:
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.sender_email, self.sender_password)
            logging.info("Email connection test successful")
            return True
        except Exception as e:
            logging.error(f"Email connection test failed: {e}")
            return False