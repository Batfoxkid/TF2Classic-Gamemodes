cd build

mkdir -p package/cfg
mkdir -p package/addons/sourcemod/plugins

cp -r addons/sourcemod/plugins/cclassrush.smx package/addons/sourcemod/plugins
cp -r addons/sourcemod/plugins/cdeathrun.smx package/addons/sourcemod/plugins
cp -r addons/sourcemod/plugins/ctimesten.smx package/addons/sourcemod/plugins
cp -r ../cfg/randomizer_x10.cfg package/cfg
cp -r ../LICENSE.txt package