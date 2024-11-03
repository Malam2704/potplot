from flask import Flask, request, jsonify
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, db
import uuid
import os
import math

app = Flask(__name__)
CORS(app)

# Ensure the temp_images directory exists
if not os.path.exists("temp_images"):
    os.makedirs("temp_images")

# Initialize Firebase
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://potplot-cee00-default-rtdb.firebaseio.com'
})

def run_yolo_model(image_path):
    return True  # Placeholder for YOLO model

def store_pothole_data(latitude, longitude, pothole_detected):
    # Define the data structure with latitude, longitude, and pothole status
    pothole_data = {
        'latitude': latitude,
        'longitude': longitude,
        'pothole_detected': pothole_detected
    }

    # Store data in Firebase; Firebase generates a unique ID for each entry
    ref = db.reference('potholes')
    ref.push(pothole_data)

@app.route('/upload', methods=['POST'])
def upload_image():
    if 'image' not in request.files or not request.form.get('latitude') or not request.form.get('longitude'):
        return jsonify({"error": "Invalid input"}), 400

    image = request.files['image']
    latitude = float(request.form['latitude'])
    longitude = float(request.form['longitude'])

    image_path = f'temp_images/{image.filename}'
    image.save(image_path)

    # Run detection model
    pothole_detected = run_yolo_model(image_path)

    # Store data in Firebase
    store_pothole_data(latitude, longitude, pothole_detected)

    return jsonify({"status": "success", "pothole_detected": pothole_detected})

@app.route('/potholes', methods=['GET'])
def get_potholes():
    ref = db.reference('potholes')
    potholes = ref.get()
    return jsonify(potholes)

def haversine(lat1, lon1, lat2, lon2):
    # Earth radius in miles
    R = 3958.8

    # Convert latitude and longitude from degrees to radians
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])

    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = math.sin(dlat / 2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distance = R * c

    return distance

def find_nearby_potholes(latitude, longitude, radius=5):
    ref = db.reference('potholes')
    all_potholes = ref.get() or {}

    nearby_potholes = []
    for pothole_id, data in all_potholes.items():
        pothole_lat = data.get('latitude')
        pothole_lon = data.get('longitude')

        # Calculate the distance
        distance = haversine(latitude, longitude, pothole_lat, pothole_lon)

        # Check if within the specified radius
        if distance <= radius:
            nearby_potholes.append({
                "id": pothole_id,
                "latitude": pothole_lat,
                "longitude": pothole_lon,
                "pothole_detected": data.get('pothole_detected')
            })

    return nearby_potholes

from flask import request, jsonify

@app.route('/nearby', methods=['GET'])
def get_nearby_potholes():
    try:
        # Access latitude, longitude, and radius from the query string
        latitude = float(request.args.get('latitude'))
        longitude = float(request.args.get('longitude'))
        radius = float(request.args.get('radius', 5))  # Default radius is 5 miles if not provided

        print(latitude, longitude, radius)

        # Find nearby potholes
        nearby_potholes = find_nearby_potholes(latitude, longitude, radius)

        return jsonify({"nearby_potholes": nearby_potholes})
    except Exception as e:
        return jsonify({"error": str(e)}), 400


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)  
