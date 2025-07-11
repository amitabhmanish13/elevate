#!/usr/bin/env python3
"""
AI News Summary App
Collects top 10 AI tech news daily and sends email summaries.
"""

import os
import sys
import logging
import schedule
import time
from datetime import datetime
from dotenv import load_dotenv

# Import our modules
from news_collector import NewsCollector
from news_processor import NewsProcessor
from email_sender import EmailSender

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('news_summary.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

class NewsApp:
    def __init__(self):
        self.collector = NewsCollector()
        self.processor = NewsProcessor()
        self.email_sender = EmailSender()
        self.max_news_items = int(os.getenv('MAX_NEWS_ITEMS', '10'))
        
    def run_daily_summary(self):
        """Run the complete news summary process."""
        try:
            logging.info("Starting daily AI news summary process...")
            
            # Step 1: Collect news
            logging.info("Collecting AI news from sources...")
            articles = self.collector.collect_ai_news()
            logging.info(f"Collected {len(articles)} articles")
            
            if not articles:
                logging.warning("No articles found. Sending empty summary.")
                # Send email even if no news found
                self.email_sender.send_news_summary([])
                return
            
            # Step 2: Process and rank news
            logging.info("Processing and ranking articles...")
            top_articles = self.processor.process_and_rank_news(articles, self.max_news_items)
            logging.info(f"Selected top {len(top_articles)} articles")
            
            # Step 3: Send email summary
            logging.info("Sending email summary...")
            success = self.email_sender.send_news_summary(top_articles)
            
            if success:
                logging.info("Daily summary completed successfully!")
                # Log summary statistics
                avg_score = sum(a['score'] for a in top_articles) / len(top_articles) if top_articles else 0
                sources = set(a['source'] for a in top_articles)
                logging.info(f"Summary stats - Articles: {len(top_articles)}, Avg Score: {avg_score:.1f}, Sources: {len(sources)}")
            else:
                logging.error("Failed to send email summary")
                
        except Exception as e:
            logging.error(f"Error in daily summary process: {e}")
            # Try to send error notification
            try:
                error_subject = f"🚨 AI News Summary Error - {datetime.now().strftime('%B %d, %Y')}"
                error_content = f"""
🚨 **AI News Summary Error**

An error occurred while generating your daily AI news summary:

**Error:** {str(e)}
**Time:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

Please check the application logs for more details.

🤖 AI News Summary Bot
"""
                self.email_sender.send_email(error_subject, error_content)
            except:
                pass  # If we can't send error email, just log it
    
    def test_all_components(self):
        """Test all components of the application."""
        logging.info("Testing all components...")
        
        # Test 1: Email connection
        logging.info("Testing email connection...")
        if self.email_sender.test_email_connection():
            logging.info("✅ Email connection test passed")
        else:
            logging.error("❌ Email connection test failed")
            return False
        
        # Test 2: News collection (limited)
        logging.info("Testing news collection...")
        try:
            # Test with just one source
            test_articles = self.collector.fetch_rss_feed(
                'https://techcrunch.com/category/artificial-intelligence/feed/',
                'TechCrunch AI'
            )
            if test_articles:
                logging.info(f"✅ News collection test passed - found {len(test_articles)} articles")
            else:
                logging.warning("⚠️ News collection test found no articles (might be normal)")
        except Exception as e:
            logging.error(f"❌ News collection test failed: {e}")
            return False
        
        # Test 3: News processing
        logging.info("Testing news processing...")
        try:
            if test_articles:
                processed = self.processor.process_and_rank_news(test_articles[:3], 3)
                logging.info(f"✅ News processing test passed - processed {len(processed)} articles")
            else:
                logging.info("✅ News processing test skipped (no articles to process)")
        except Exception as e:
            logging.error(f"❌ News processing test failed: {e}")
            return False
        
        logging.info("🎉 All component tests completed!")
        return True
    
    def send_test_email(self):
        """Send a test email to verify the setup."""
        logging.info("Sending test email...")
        
        test_articles = [{
            'title': 'Test AI News Article',
            'url': 'https://example.com',
            'summary': 'This is a test article to verify that your AI news summary email system is working correctly.',
            'source': 'Test Source',
            'published': datetime.now(),
            'score': 8.5,
            'ai_summary': 'This is a test email to confirm your AI news summary system is properly configured and working.'
        }]
        
        success = self.email_sender.send_news_summary(test_articles)
        if success:
            logging.info("✅ Test email sent successfully!")
        else:
            logging.error("❌ Failed to send test email")
        return success

def main():
    """Main application entry point."""
    app = NewsApp()
    
    # Parse command line arguments
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()
        
        if command == 'test':
            # Run tests
            app.test_all_components()
            
        elif command == 'test-email':
            # Send test email
            app.send_test_email()
            
        elif command == 'run-once':
            # Run summary once
            app.run_daily_summary()
            
        elif command == 'schedule':
            # Run with scheduler
            send_time = os.getenv('SEND_TIME', '09:00')
            logging.info(f"Scheduling daily summary at {send_time}")
            
            schedule.every().day.at(send_time).do(app.run_daily_summary)
            
            logging.info("Scheduler started. Press Ctrl+C to stop.")
            
            try:
                while True:
                    schedule.run_pending()
                    time.sleep(60)  # Check every minute
            except KeyboardInterrupt:
                logging.info("Scheduler stopped by user")
                
        else:
            print("Unknown command. Available commands:")
            print("  test       - Test all components")
            print("  test-email - Send a test email")
            print("  run-once   - Run summary once")
            print("  schedule   - Run with daily scheduler")
    else:
        # Default: run once
        print("Running AI news summary once...")
        app.run_daily_summary()

if __name__ == "__main__":
    main()