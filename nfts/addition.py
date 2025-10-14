import os
import json

# Define the multipliers for rarities
rarity_addition = {
    "Common": 0,
    "Rare": 1,
    "Epic": 3,
    "Legendary": 5
}

# Calculate addition value based on rarity
def calculate_addition(attributes):
    addition = 0
    for attribute in attributes:
        rarity = attribute.get("value")
        addition += rarity_addition.get(rarity, 0)  # Default to 0 if rarity is missing
    return addition

# Update JSON files
def update_json_files(directory):
    for filename in os.listdir(directory):
        if filename.endswith(".json") and filename != "_metadata.json":
            filepath = os.path.join(directory, filename)
            
            # Read the JSON file
            with open(filepath, "r") as file:
                data = json.load(file)

            # Calculate the addition value
            attributes = data.get("attributes", [])
            addition = calculate_addition(attributes)

            # Update JSON
            data["addition"] = addition

            # Write back to the JSON file
            with open(filepath, "w") as file:
                json.dump(data, file, indent=4)

            print(f"Updated {filename} with addition: {addition}")

# Specify the directory containing the JSON files
directory = "" # CHANGE ACCORDINGLY
update_json_files(directory)
