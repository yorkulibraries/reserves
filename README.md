# Reserves

# Start developing

```
git clone https://github.com/yorkulibraries/reserves.git
cd reserves
docker compose up --build
```

There are 2 containers created: *reserves-web-1* and *reserves-dbl-1*

# Access the front end web app in DEVELOPMENT 

By default, the application will listen on port 4004 and runs with RAILS_ENV=development.

To access the application in Chrome browser, you will need to add the ModHeader extension to your Chrome browser.

Once the extension has been activated, you can add the following header to the site http://localhost:4004/. This will enable you to login as **manager** user.

Header: PYORK_USER

Value: manager

The application is now accessible at http://localhost:4004/

# What if I want to use a different port?

If you wish to use a different port, you can set the PORT environment 

```
PORT=4005 docker compose up --build
```

# Run tests

Start the containers if you haven't started them yet.

```
docker compose up --build
```

Run the tests

```
docker exec -it  -e RAILS_ENV=test -e DATABASE_URL=sqlite3:db/test.sqlite3 reserves-web-1 rails test
```

# Access the containers

DB container
```
docker exec -it reserves-db-1 bash
```

Webapp container
```
docker exec -it reserves-web-1 bash
```

