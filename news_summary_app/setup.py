#!/usr/bin/env python3
"""
Setup script for AI News Summary App
Helps with installation and configuration
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path

def run_command(command, description):
    """Run a shell command with error handling."""
    print(f"\n🔧 {description}...")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} failed: {e.stderr}")
        return False

def check_python_version():
    """Check if Python version is compatible."""
    print("🐍 Checking Python version...")
    version = sys.version_info
    if version.major >= 3 and version.minor >= 8:
        print(f"✅ Python {version.major}.{version.minor}.{version.micro} is compatible")
        return True
    else:
        print(f"❌ Python {version.major}.{version.minor}.{version.micro} is not compatible. Please use Python 3.8 or higher.")
        return False

def install_dependencies():
    """Install required Python packages."""
    print("\n📦 Installing dependencies...")
    
    # Check if pip is available
    try:
        subprocess.run([sys.executable, "-m", "pip", "--version"], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        print("❌ pip is not available. Please install pip first.")
        return False
    
    # Install requirements
    return run_command(
        f"{sys.executable} -m pip install -r requirements.txt",
        "Installing Python packages"
    )

def create_env_file():
    """Create .env file from template."""
    print("\n⚙️ Setting up environment configuration...")
    
    env_example = Path(".env.example")
    env_file = Path(".env")
    
    if not env_example.exists():
        print("❌ .env.example file not found")
        return False
    
    if env_file.exists():
        overwrite = input("📁 .env file already exists. Overwrite? (y/N): ").lower()
        if overwrite != 'y':
            print("⏭️ Skipping .env file creation")
            return True
    
    try:
        shutil.copy(env_example, env_file)
        print("✅ .env file created successfully")
        print("⚠️  Please edit .env file with your email credentials before running the app")
        return True
    except Exception as e:
        print(f"❌ Failed to create .env file: {e}")
        return False

def configure_email():
    """Interactive email configuration."""
    print("\n📧 Email Configuration")
    print("This app uses Gmail SMTP to send emails.")
    print("You'll need:")
    print("  1. A Gmail account")
    print("  2. 2-Factor Authentication enabled")
    print("  3. An App Password generated")
    print()
    
    configure = input("Would you like to configure email settings now? (y/N): ").lower()
    if configure != 'y':
        print("⏭️ Skipping email configuration. Remember to edit .env file manually.")
        return True
    
    # Get email settings
    sender_email = input("📤 Enter your Gmail address: ").strip()
    if not sender_email or '@' not in sender_email:
        print("❌ Invalid email address")
        return False
    
    app_password = input("🔑 Enter your Gmail App Password (16 characters): ").strip()
    if not app_password or len(app_password) != 16:
        print("❌ App Password should be 16 characters")
        return False
    
    recipient_email = input(f"📥 Enter recipient email (default: amitabhmanish13@gmail.com): ").strip()
    if not recipient_email:
        recipient_email = "amitabhmanish13@gmail.com"
    
    send_time = input("⏰ Enter daily send time in HH:MM format (default: 09:00): ").strip()
    if not send_time:
        send_time = "09:00"
    
    max_items = input("📊 Enter maximum number of news items (default: 10): ").strip()
    if not max_items:
        max_items = "10"
    
    # Update .env file
    try:
        env_content = f"""# Email Configuration
EMAIL_SENDER={sender_email}
EMAIL_PASSWORD={app_password}
EMAIL_RECIPIENT={recipient_email}
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587

# Optional: OpenAI API Key for AI-powered news filtering and summarization
OPENAI_API_KEY=your_openai_api_key_here

# News Sources Configuration
MAX_NEWS_ITEMS={max_items}
SUMMARY_LENGTH=short

# Scheduling
SEND_TIME={send_time}
"""
        
        with open('.env', 'w') as f:
            f.write(env_content)
        
        print("✅ Email configuration saved to .env file")
        return True
        
    except Exception as e:
        print(f"❌ Failed to save configuration: {e}")
        return False

def test_installation():
    """Test the installation."""
    print("\n🧪 Testing installation...")
    
    # Test imports
    try:
        from news_collector import NewsCollector
        from news_processor import NewsProcessor
        from email_sender import EmailSender
        print("✅ All modules imported successfully")
    except ImportError as e:
        print(f"❌ Import error: {e}")
        return False
    
    # Test basic functionality
    try:
        collector = NewsCollector()
        processor = NewsProcessor()
        print("✅ Core modules initialized successfully")
    except Exception as e:
        print(f"❌ Initialization error: {e}")
        return False
    
    print("✅ Installation test passed")
    return True

def show_next_steps():
    """Show next steps to the user."""
    print("\n🎉 Setup completed successfully!")
    print("\n📋 Next Steps:")
    print("  1. Verify your .env file configuration")
    print("  2. Test email connection: python main.py test")
    print("  3. Send test email: python main.py test-email")
    print("  4. Run once: python main.py run-once")
    print("  5. Schedule daily: python main.py schedule")
    print("\n📚 For more information, read the README.md file")
    print("🐛 For troubleshooting, check the logs in news_summary.log")

def main():
    """Main setup function."""
    print("🤖 AI News Summary App Setup")
    print("=" * 40)
    
    # Check Python version
    if not check_python_version():
        sys.exit(1)
    
    # Install dependencies
    if not install_dependencies():
        print("\n❌ Setup failed during dependency installation")
        sys.exit(1)
    
    # Create environment file
    if not create_env_file():
        print("\n❌ Setup failed during environment configuration")
        sys.exit(1)
    
    # Configure email (optional)
    configure_email()
    
    # Test installation
    if not test_installation():
        print("\n❌ Setup failed during testing")
        sys.exit(1)
    
    # Show next steps
    show_next_steps()

if __name__ == "__main__":
    main()