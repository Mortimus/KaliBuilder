#!/bin/bash

PROJECT_NAME="noPac"
REPO="https://github.com/Ridter/noPac"
PROGRAM="noPac.py"
PROGRAM1="scanner.py"

mkdir /opt/$PROJECT_NAME
git clone $REPO /opt/$PROJECT_NAME
chmod -R 755 /opt/$PROJECT_NAME/
# virtualize
mkdir /opt/mycompany/virtual/env/$PROJECT_NAME
virtualenv /opt/mycompany/virtual/env/$PROJECT_NAME/.venv
source /opt/mycompany/virtual/env/$PROJECT_NAME/.venv/bin/activate
pip install -r /opt/$PROJECT_NAME/requirements.txt
deactivate

# Make wrapper launcher
touch /opt/mycompany/virtual/$PROJECT_NAME.sh
echo "#!/bin/bash" >> /opt/mycompany/virtual/$PROJECT_NAME.sh
echo "source /opt/mycompany/virtual/env/$PROJECT_NAME/.venv/bin/activate" >> /opt/mycompany/virtual/$PROJECT_NAME.sh
echo "python3 /opt/$PROJECT_NAME/$PROGRAM $@" >> /opt/mycompany/virtual/$PROJECT_NAME.sh
echo "deactivate" >> /opt/mycompany/virtual/$PROJECT_NAME.sh

# Make executable
chmod +x /opt/mycompany/virtual/$PROJECT_NAME.sh

# Link
ln -s /opt/mycompany/virtual/$PROJECT_NAME.sh /usr/bin/$PROGRAM

# Make wrapper launcher for program2
touch /opt/mycompany/virtual/$PROGRAM2.sh
echo "#!/bin/bash" >> /opt/mycompany/virtual/$PROGRAM2.sh
echo "source /opt/mycompany/virtual/env/$PROJECT_NAME/.venv/bin/activate" >> /opt/mycompany/virtual/$PROGRAM2.sh
echo "python3 /opt/$PROJECT_NAME/$PROGRAM2 $@" >> /opt/mycompany/virtual/$PROGRAM2.sh
echo "deactivate" >> /opt/mycompany/virtual/$PROGRAM2.sh

# Make executable
chmod +x /opt/mycompany/virtual/$PROGRAM2.sh

# Link
ln -s /opt/mycompany/virtual/$PROGRAM2.sh /usr/bin/$PROGRAM2