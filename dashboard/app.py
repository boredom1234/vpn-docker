from flask import Flask, render_template, jsonify, request
import subprocess
import os
import time
import psutil
from werkzeug.utils import secure_filename

app = Flask(__name__)

LOG_DIR = "/var/log/vpn"
OVPN_LOG = os.path.join(LOG_DIR, "openvpn.log")


def get_vpn_ip():
    try:
        # Try to get IP through the tunnel
        result = subprocess.check_output(
            [
                "curl",
                "--interface",
                "tun0",
                "-s",
                "--max-time",
                "2",
                "https://ifconfig.me",
            ],
            text=True,
        )
        return result.strip()
    except subprocess.CalledProcessError:
        return "Unknown"
    except Exception:
        return "Unknown"


def get_uptime():
    try:
        with open("/proc/uptime", "r") as f:
            uptime_seconds = float(f.readline().split()[0])
            return time.strftime("%H:%M:%S", time.gmtime(uptime_seconds))
    except Exception:
        return "00:00:00"


def get_traffic():
    try:
        # Get stats for tun0
        stats = psutil.net_io_counters(pernic=True).get("tun0")
        if stats:
            return {"rx": stats.bytes_recv, "tx": stats.bytes_sent}
        return {"rx": 0, "tx": 0}
    except Exception:
        return {"rx": 0, "tx": 0}


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/status")
def status():
    vpn_status = (
        "Connected" if os.path.exists("/sys/class/net/tun0") else "Disconnected"
    )

    return jsonify(
        {
            "vpn_status": vpn_status,
            "public_ip": get_vpn_ip() if vpn_status == "Connected" else "N/A",
            "uptime": get_uptime(),
            "traffic": get_traffic(),
        }
    )


@app.route("/api/logs")
def logs():
    log_type = request.args.get("type", "openvpn")
    log_file = OVPN_LOG
    
    if log_type == "tinyproxy":
        log_file = os.path.join(LOG_DIR, "tinyproxy.log")
    elif log_type == "dante":
        log_file = os.path.join(LOG_DIR, "danted.log")

    try:
        if not os.path.exists(log_file):
            return jsonify({"logs": f"Log file not found: {log_file}"})
            
        # Read last 100 lines
        cmd = f"tail -n 100 {log_file}"
        output = subprocess.check_output(cmd, shell=True, text=True)
        return jsonify({"logs": output})
    except Exception as e:
        return jsonify({"logs": str(e)})


@app.route("/api/restart", methods=["POST"])
def restart_vpn():
    try:
        # Kill openvpn, watchdog will restart it
        subprocess.run(["killall", "openvpn"])
        return jsonify({"status": "success", "message": "VPN restarting..."})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})


@app.route("/api/configs", methods=["GET"])
def list_configs():
    try:
        configs = []
        active_config = ""
        
        if os.path.exists("/etc/vpn-active-config"):
            with open("/etc/vpn-active-config", "r") as f:
                active_config = f.read().strip()

        for filename in os.listdir("/vpn"):
            if filename.endswith(".ovpn"):
                full_path = os.path.join("/vpn", filename)
                configs.append({
                    "name": filename,
                    "active": full_path == active_config
                })
        
        return jsonify({"configs": configs})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/configs/upload", methods=["POST"])
def upload_config():
    try:
        if "file" not in request.files:
            return jsonify({"error": "No file part"}), 400
        
        file = request.files["file"]
        if file.filename == "":
            return jsonify({"error": "No selected file"}), 400
            
        if file and file.filename.endswith(".ovpn"):
            filename = secure_filename(file.filename)
            file.save(os.path.join("/vpn", filename))
            return jsonify({"message": "File uploaded successfully"})
            
        return jsonify({"error": "Invalid file type"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/configs/activate", methods=["POST"])
def activate_config():
    try:
        data = request.get_json()
        filename = data.get("filename")
        
        if not filename:
            return jsonify({"error": "Filename required"}), 400
            
        config_path = os.path.join("/vpn", filename)
        if not os.path.exists(config_path):
            return jsonify({"error": "Config file not found"}), 404
            
        # Update active config pointer
        with open("/etc/vpn-active-config", "w") as f:
            f.write(config_path)
            
        # Kill openvpn to trigger watchdog restart with new config
        subprocess.run(["killall", "openvpn"])
        
        return jsonify({"message": "Switching configuration..."})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/configs/delete", methods=["POST"])
def delete_config():
    try:
        data = request.get_json()
        filename = data.get("filename")
        
        if not filename:
            return jsonify({"error": "Filename required"}), 400
            
        config_path = os.path.join("/vpn", filename)
        
        # Check if active
        active_config = ""
        if os.path.exists("/etc/vpn-active-config"):
            with open("/etc/vpn-active-config", "r") as f:
                active_config = f.read().strip()
                
        if config_path == active_config:
            return jsonify({"error": "Cannot delete active configuration"}), 400
            
        if os.path.exists(config_path):
            os.remove(config_path)
            return jsonify({"message": "Configuration deleted"})
            
        return jsonify({"error": "File not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9090)
