#!/bin/bash

# Set Google Cloud project (replace with your actual project ID)
PROJECT_ID="alert-rain-435902-u0"
gcloud config set project $PROJECT_ID

# Define VMs and their corresponding zones
declare -A VMS_ZONES
VMS_ZONES=(
  ["flask-vm-us-east"]="us-east1-b"
  ["flask-vm-us-central1"]="us-central1-a"
  ["flask-vm-us-west"]="us-west1-a"
  ["flask-vm-europe-west"]="europe-west1-b"
  ["flask-vm-europe-north"]="europe-north1-a"
  ["flask-vm-asia-east"]="asia-east1-a"
  ["flask-vm-asia-southeast"]="asia-southeast1-a"
)

# Path to the Flask app (assumes app.py is in the same directory as this script)
APP_FILE="app.py"
APP_CENTRAL_FILE="app_central.py"

# Check if files exist
if [ ! -f "$APP_FILE" ]; then
  echo "Error: $APP_FILE not found!"
  exit 1
fi 

if [ ! -f "$APP_CENTRAL_FILE" ]; then
  echo "Error: $APP_CENTRAL_FILE not found!"
  exit 1
fi


# Loop through each VM, transfer the app.py file, and run the Flask app concurrently
for INSTANCE_NAME in "${!VMS_ZONES[@]}"; do
  ZONE=${VMS_ZONES[$INSTANCE_NAME]}

  # Run the operations in the background
  (
    if [ "$INSTANCE_NAME" == "flask-vm-us-east" ]; then
      # make first VM instance the central node 
      # transfer APP_CENTRAL_FILE
      echo "This is the first instance: $INSTANCE_NAME in zone $ZONE"
      gcloud compute scp $APP_CENTRAL_FILE $INSTANCE_NAME:/tmp/ --zone=$ZONE
      # rename file 
      gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="mv /tmp/$APP_CENTRAL_FILE /tmp/app.py"
    else
      # for all other instances, transfer APP_FILE instead
      echo "Transferring $APP_FILE to $INSTANCE_NAME in zone $ZONE..."
      gcloud compute scp $APP_FILE $INSTANCE_NAME:/tmp/ --zone=$ZONE
    fi
    # Ensure Flask is installed on the VM
    echo "Ensuring Flask is installed on $INSTANCE_NAME..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="pip3 show flask || sudo pip3 install flask"

    echo "Running Flask app on $INSTANCE_NAME..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="cd /tmp/ && nohup python3 app.py --host=0.0.0.0 > /dev/null 2>&1 &"
  ) &

done



# Wait for all background jobs to finish
wait

echo "Flask app is running on all VMs. Access them using their external IPs on port 5000."
