import os
import sys
import subprocess
import webbrowser
import time

def main():
    print("=" * 60)
    print(" 🚀 Enterprise Face Recognition Attendance System")
    print("=" * 60)
    
    backend_dir = os.path.join(os.path.dirname(__file__), "backend")
    
    print("\n[1/2] Starting FastAPI Backend Server on http://localhost:8000 ...")
    
    # Run Uvicorn server
    cmd = [sys.executable, "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
    
    try:
        # Open web browser after a short delay
        print("[2/2] Opening Web Kiosk Interface in default browser...")
        time.sleep(2)
        webbrowser.open("http://localhost:8000/")
        
        subprocess.run(cmd, cwd=backend_dir)
    except KeyboardInterrupt:
        print("\n[!] Server stopped by user.")
    except Exception as e:
        print(f"\n[X] Error starting server: {e}")

if __name__ == "__main__":
    main()
