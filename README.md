# Reserves

# Start developing

```
git clone https://github.com/yorkulibraries/reserves.git
cd reserves
docker compose up --build
```

There are 3 containers created: **web**, **db** and **mailcatcher**

# Access the front end web app in DEVELOPMENT 

By default, the application will listen on port 3006 and runs with RAILS_ENV=development.

To access the application in Chrome browser, you will need to add the ModHeader extension to your Chrome browser.

Once the extension has been activated, you can add the following header to the site http://localhost:3006/. This will enable you to login as **manager** user.

Header: PYORK_USER

Value: manager

The application is now accessible at http://localhost:3006/

# Access mailcatcher web app

http://localhost:3086/

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
docker compose exec web rts
```

Run all tests in a specific test file
```
docker compose exec web bash
rt test/models/user_test.rb
```

Run a specific test
```
docker compose exec web bash
rt test/models/user_test.rb:14
```

