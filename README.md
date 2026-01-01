# personal_outfit_recommendation

A Flutter project.

## Getting Started

### 1. Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
* A running instance of the **Python Backend** [Clip-backend](https://github.com/hockXiang025/clip-backend).

### 2. Environment Setup
This project uses `flutter_dotenv` to manage sensitive API keys. You must configure this before running the app.

1.  **Duplicate the template file:**
    Copy the `.env.template` file in the root directory and rename the copy to `.env`.

    * **Mac/Linux:**
        ```bash
        cp .env.template .env
        ```
    * **Windows:**
        ```cmd
        copy .env.template .env
        ```

2.  **Configure your keys:**
    Open the new `.env` file and fill in your actual values

### 3. Install Dependencies
Run the following command to install all required Flutter packages:

```bash
flutter pub get

