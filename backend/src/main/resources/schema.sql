CREATE TABLE IF NOT EXISTS users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    gender VARCHAR(10),
    age INT
);

CREATE TABLE IF NOT EXISTS movies (
    movie_id INT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    release_year INT,
    genres VARCHAR(255),
    director VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS ratings (
    rating_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    movie_id INT NOT NULL,
    score FLOAT NOT NULL,
    timestamp BIGINT,
    CONSTRAINT fk_rating_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_rating_movie FOREIGN KEY (movie_id) REFERENCES movies(movie_id)
);

CREATE TABLE IF NOT EXISTS recommendations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    movie_id INT NOT NULL,
    predicted_score FLOAT,
    reason TEXT,
    CONSTRAINT fk_rec_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_rec_movie FOREIGN KEY (movie_id) REFERENCES movies(movie_id)
);
