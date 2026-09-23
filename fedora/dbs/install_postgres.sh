sudo dnf install postgresql-server postgresql-contrib -y
sudo systemctl enable postgresql
sudo postgresql-setup --initdb --unit postgresql
sudo systemctl start postgresql
