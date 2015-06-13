cp -r ~/Python-2.7.6/ ./vendor/Python
mkdir -p ./bin
echo "#!/usr/bin/env bash" > ./bin/python
echo "PROJECT_ROOT=\$( cd \"\$( dirname \"\${BASH_SOURCE[0]}\" )\" && pwd )/../vendor/Python" >> ./bin/python
echo "exec \$PROJECT_ROOT/python \"\$@\"" >> ./bin/python
chmod +x ./bin/python

