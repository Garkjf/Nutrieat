# NutriEat

NutriEat is a nutrition-based food and recipe recommendation mobile application developed as part of the 6003CMD Dissertation and Project Artefact module at Coventry University. The system is designed to provide nutritional food and recipe suggestions while following a privacy-preserving approach.

The frontend of NutriEat was developed using Flutter and Dart, providing a cross-platform mobile interface for food tracking, recommendation generation, recipe browsing, and map-based food location search.

## Project Overview

NutriEat addresses this by combining a mobile frontend with a hybrid recommendation backend.

This repository contains the **Flutter frontend** for the NutriEat application.

## Key Features

- User authentication (login, register, password recovery)
- Daily food diary and intake tracking
- Nutritional overview dashboard
- Personalised food and recipe recommendation interface
- Recipe browsing and saved recipe view
- Google Maps integration for nearby food locations
- Firebase integration for user data storage

## Frontend Pages

The application includes the following main pages:

- Login Page
- Register Page
- Forget Password Page
- Home Dashboard
- Diary Page
- Recipe Page
- Recommendation Page
- Recommendation History Page
- Map Integration Page
- Settings and Profile Pages

## Technology Stack

- **Framework:** Flutter
- **Language:** Dart
- **Backend Communication:** HTTP requests to Flask API
- **Database / Cloud Services:** Firebase Firestore
- **Maps Integration:** Google Maps API


## Repository Purpose

This repository focuses on the **frontend implementation** of the NutriEat system. It is responsible for:

- user interaction
- navigation
- page rendering
- API request handling
- displaying recommendation results
- integrating Firebase and Google Maps services

## Related Repository

Backend repository:

`[Nutrieat_Recommendation_System](https://github.coventry.ac.uk/garkj/Nutrieat_Recommendation_System)`

This backend repository contains the Flask recommendation engine, hybrid recommendation logic, and supporting machine learning components.

## Setup Instructions

### Prerequisites

Make sure you have installed:

- Flutter SDK
- Dart SDK
- Android Studio or VS Code
- Firebase project configuration
- Google Maps API key

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.coventry.ac.uk/garkj/NutriEat.git
   git clone https://github.coventry.ac.uk/garkj/Nutrieat_Recommendation_System.git
