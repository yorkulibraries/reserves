# Reserves

# Start developing

```
git clone https://github.com/yorkulibraries/reserves.git
cd reserves
docker compose up --build
```

There are 2 containers created: *reserves-web-1* and *reserves-dbl-1*

# Access the front end web app in DEVELOPMENT 

By default, the application will listen on port 3006 and runs with RAILS_ENV=development.

To access the application in Chrome browser, you will need to add the ModHeader extension to your Chrome browser.

Once the extension has been activated, you can add the following header to the site http://localhost:3006/. This will enable you to login as **manager** user.

Header: PYORK_USER

Value: manager

The application is now accessible at http://localhost:3006/

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

Run all the tests

```
docker compose exec web rt 
```

Run a specific test and test within the test file.
```
docker compose exec web rt TEST=test/controllers/users_controller_test.rb

1. docker compose exec web bash
2. $>  rts TEST=test/system/requests_test.rb

```

# Access the containers

DB container
```
docker compose exec db bash
```

Webapp container
```
docker compose exec web bash
```

