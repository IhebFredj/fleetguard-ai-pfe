New-Item -ItemType Directory -Force -Path 'd:\gestionCamion\fleetguard\assets\models'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb' -OutFile 'd:\gestionCamion\fleetguard\assets\models\truck.glb'
