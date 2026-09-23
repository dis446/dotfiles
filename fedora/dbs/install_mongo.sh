sudo tee /etc/yum.repos.d/mongodb-org-8.0.repo > /dev/null << 'EOF'
[mongodb-org-8.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/8.0/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
EOF

sudo dnf install -y mongodb-org

sudo systemctl enable --now mongod
