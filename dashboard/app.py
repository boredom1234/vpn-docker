from flask import Flask, render_template, jsonify
import subprocess
import os
import time
import psutil

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
    try:
        # Read last 50 lines of openvpn log
        cmd = f"tail -n 50 {OVPN_LOG}"
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


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9090)
