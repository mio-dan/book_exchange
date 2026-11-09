CREATE DATABASE book_exchange;

USE book_exchange;


CREATE TABLE `User` (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(45) NOT NULL,
    email VARCHAR(45) NOT NULL,
    phone VARCHAR(10),
    is_admin TINYINT NOT NULL DEFAULT 0,
    CONSTRAINT uq_user_email UNIQUE (email),
    CONSTRAINT chk_user_is_admin
        CHECK (is_admin IN (0, 1))
);

CREATE TABLE Address (
    address_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    street VARCHAR(100),
    postal_code VARCHAR(10),
    city VARCHAR(45),
    FOREIGN KEY (user_id) REFERENCES `User`(user_id)
);

CREATE TABLE Author (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(45)
);

CREATE TABLE Genre (
    genre_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(45)
);

CREATE TABLE Book (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(150),
    publisher VARCHAR(45),
    publication_year INT,
    language VARCHAR(45)
);

CREATE TABLE BookAuthor (
    book_id INT,
    author_id INT,
    PRIMARY KEY (book_id, author_id),
    FOREIGN KEY (book_id) REFERENCES Book(book_id),
    FOREIGN KEY (author_id) REFERENCES Author(author_id)
);

CREATE TABLE BookGenre (
    book_id INT,
    genre_id INT,
    PRIMARY KEY (book_id, genre_id),
    FOREIGN KEY (book_id) REFERENCES Book(book_id),
    FOREIGN KEY (genre_id) REFERENCES Genre(genre_id)
);

CREATE TABLE BookCopy (
    copy_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT,
    owner_id INT,
    `condition` VARCHAR(45),
    max_loan_days INT NOT NULL,
    shipping TINYINT NOT NULL DEFAULT 0,

    FOREIGN KEY (book_id)
        REFERENCES Book(book_id),

    FOREIGN KEY (owner_id)
        REFERENCES `User`(user_id),

    CONSTRAINT chk_bookcopy_max_loan_days
        CHECK (max_loan_days > 0),

    CONSTRAINT chk_bookcopy_shipping
        CHECK (shipping IN (0, 1))
);

CREATE TABLE PickupLocation (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    copy_id INT,
    address_id INT,
    FOREIGN KEY (copy_id) REFERENCES BookCopy(copy_id),
    FOREIGN KEY (address_id) REFERENCES Address(address_id)
);

CREATE TABLE TimeSlot (
    timeslot_id INT AUTO_INCREMENT PRIMARY KEY,
    location_id INT,
    `date` DATE,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,

    FOREIGN KEY (location_id)
        REFERENCES PickupLocation(location_id),

    CONSTRAINT chk_timeslot_time
        CHECK (end_time > start_time)
);

CREATE TABLE Loan (
    loan_id INT AUTO_INCREMENT PRIMARY KEY,
    copy_id INT NOT NULL,
    loan_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,
    borrower_id INT,
    timeslot_id INT NULL,

    active_copy_id INT
        GENERATED ALWAYS AS (
            CASE
                WHEN return_date IS NULL THEN copy_id
                ELSE NULL
            END
        ) STORED,

    FOREIGN KEY (copy_id)
        REFERENCES BookCopy(copy_id),

    FOREIGN KEY (borrower_id)
        REFERENCES `User`(user_id),

    CONSTRAINT fk_loan_timeslot
        FOREIGN KEY (timeslot_id)
        REFERENCES TimeSlot(timeslot_id),

    CONSTRAINT chk_loan_due_date
        CHECK (due_date >= loan_date),

    CONSTRAINT chk_loan_return_date
        CHECK (
            return_date IS NULL
            OR return_date >= loan_date
        ),

    CONSTRAINT uq_loan_active_copy
        UNIQUE (active_copy_id)
);

CREATE VIEW BookCopyAvailability AS
SELECT
    bc.copy_id,
    bc.book_id,
    bc.owner_id,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM Loan l
            WHERE l.copy_id = bc.copy_id
              AND l.return_date IS NULL
        )
        THEN 0
        ELSE 1
    END AS available
FROM BookCopy bc;

CREATE TABLE Review (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT,
    user_id INT,
    rating TINYINT NOT NULL,
    comment VARCHAR(500),

    FOREIGN KEY (book_id) REFERENCES Book(book_id),
    FOREIGN KEY (user_id) REFERENCES `User`(user_id),

    CONSTRAINT chk_review_rating
        CHECK (rating BETWEEN 1 AND 5)
);

DELIMITER $$

CREATE TRIGGER trg_pickuplocation_owner_insert
BEFORE INSERT ON PickupLocation
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM BookCopy bc
        JOIN Address a
            ON a.user_id = bc.owner_id
        WHERE bc.copy_id = NEW.copy_id
          AND a.address_id = NEW.address_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Abholadresse gehoert nicht dem Bucheigentuemer';
    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_pickuplocation_owner_update
BEFORE UPDATE ON PickupLocation
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM BookCopy bc
        JOIN Address a
            ON a.user_id = bc.owner_id
        WHERE bc.copy_id = NEW.copy_id
          AND a.address_id = NEW.address_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Abholadresse gehoert nicht dem Bucheigentuemer';
    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_bookcopy_owner_update
BEFORE UPDATE ON BookCopy
FOR EACH ROW
BEGIN
    IF NOT (NEW.owner_id <=> OLD.owner_id)
       AND EXISTS (
           SELECT 1
           FROM PickupLocation pl
           JOIN Address a
               ON a.address_id = pl.address_id
           WHERE pl.copy_id = OLD.copy_id
             AND NOT (a.user_id <=> NEW.owner_id)
       )
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Eigentuemerwechsel widerspricht der Abholadresse';
    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_address_owner_update
BEFORE UPDATE ON Address
FOR EACH ROW
BEGIN
    IF NOT (NEW.user_id <=> OLD.user_id)
       AND EXISTS (
           SELECT 1
           FROM PickupLocation pl
           JOIN BookCopy bc
               ON bc.copy_id = pl.copy_id
           WHERE pl.address_id = OLD.address_id
             AND NOT (bc.owner_id <=> NEW.user_id)
       )
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Adresszuordnung widerspricht dem Bucheigentuemer';
    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_loan_timeslot_insert
BEFORE INSERT ON Loan
FOR EACH ROW
BEGIN
    IF NEW.timeslot_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM TimeSlot ts
           JOIN PickupLocation pl
               ON pl.location_id = ts.location_id
           WHERE ts.timeslot_id = NEW.timeslot_id
             AND pl.copy_id = NEW.copy_id
       )
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Zeitfenster gehoert nicht zum Buchexemplar';
    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_loan_timeslot_update
BEFORE UPDATE ON Loan
FOR EACH ROW
BEGIN
    IF NEW.timeslot_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM TimeSlot ts
           JOIN PickupLocation pl
               ON pl.location_id = ts.location_id
           WHERE ts.timeslot_id = NEW.timeslot_id
             AND pl.copy_id = NEW.copy_id
       )
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Zeitfenster gehoert nicht zum Buchexemplar';
    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_timeslot_location_update
BEFORE UPDATE ON TimeSlot
FOR EACH ROW
BEGIN
    IF NOT (NEW.location_id <=> OLD.location_id)
       AND EXISTS (
           SELECT 1
           FROM Loan l
           LEFT JOIN PickupLocation pl
               ON pl.location_id = NEW.location_id
              AND pl.copy_id = l.copy_id
           WHERE l.timeslot_id = OLD.timeslot_id
             AND pl.location_id IS NULL
       )
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Zeitfensteraenderung widerspricht der Ausleihe';
    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_pickuplocation_copy_update
BEFORE UPDATE ON PickupLocation
FOR EACH ROW
BEGIN
    IF NOT (NEW.copy_id <=> OLD.copy_id)
       AND EXISTS (
           SELECT 1
           FROM TimeSlot ts
           JOIN Loan l
               ON l.timeslot_id = ts.timeslot_id
           WHERE ts.location_id = OLD.location_id
             AND NOT (l.copy_id <=> NEW.copy_id)
       )
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Abholortaenderung widerspricht der Ausleihe';
    END IF;
END$$

DELIMITER ;

INSERT INTO `User` (name, email, phone, is_admin) VALUES
('Anna Müller', 'anna.mueller@mail.de', '0151123456', 0),
('Lukas Weber', 'lukas.weber@mail.de', '0152234567', 0),
('Sophie Bauer', 'sophie.bauer@mail.de', '0153345678', 0),
('Jonas Wagner', 'jonas.wagner@mail.de', '0154456789', 0),
('Laura Fischer', 'laura.fischer@mail.de', '0155567890', 0),
('Felix Schneider', 'felix.schneider@mail.de', '0156678901', 0),
('Emma Hoffmann', 'emma.hoffmann@mail.de', '0157789012', 0),
('Noah Becker', 'noah.becker@mail.de', '0158890123', 0),
('Mia Koch', 'mia.koch@mail.de', '0159901234', 0),
('Max Richter', 'max.richter@mail.de', '0151012345', 1);

SELECT * FROM `User`;

INSERT INTO Address (user_id, street, postal_code, city) VALUES
(1, 'Hauptstrasse 12', '6020', 'Innsbruck'),
(2, 'Museumstrasse 8', '6020', 'Innsbruck'),
(3, 'Bahnhofstrasse 15', '6060', 'Hall'),
(4, 'Dorfstrasse 21', '6176', 'Voels'),
(5, 'Kirchplatz 4', '6063', 'Rum'),
(6, 'Bergweg 9', '6162', 'Mutters'),
(7, 'Innrain 35', '6020', 'Innsbruck'),
(8, 'Amraser Strasse 18', '6020', 'Innsbruck'),
(9, 'Tiroler Strasse 27', '6401', 'Inzing'),
(10, 'Seestrasse 6', '6072', 'Lans');

SELECT * FROM Address;

INSERT INTO Author (name) VALUES
('George Orwell'),
('J. K. Rowling'),
('J. R. R. Tolkien'),
('Stephen King'),
('Jane Austen'),
('Franz Kafka'),
('Hermann Hesse'),
('Agatha Christie'),
('Erich Kaestner'),
('Michael Ende');

SELECT * FROM Author;

INSERT INTO Genre (name) VALUES
('Dystopie'),
('Fantasy'),
('Horror'),
('Klassiker'),
('Roman'),
('Krimi'),
('Science-Fiction'),
('Abenteuer'),
('Kinderbuch'),
('Drama');

SELECT * FROM Genre;

INSERT INTO Book (title, publisher, publication_year, language) VALUES
('1984', 'Secker & Warburg', 1949, 'Englisch'),
('Harry Potter und der Stein der Weisen', 'Carlsen', 1997, 'Deutsch'),
('Der Hobbit', 'George Allen & Unwin', 1937, 'Englisch'),
('Es', 'Viking Press', 1986, 'Englisch'),
('Stolz und Vorurteil', 'T. Egerton', 1813, 'Englisch'),
('Die Verwandlung', 'Kurt Wolff Verlag', 1915, 'Deutsch'),
('Siddhartha', 'S. Fischer Verlag', 1922, 'Deutsch'),
('Mord im Orient-Express', 'Collins Crime Club', 1934, 'Englisch'),
('Emil und die Detektive', 'Williams & Co.', 1929, 'Deutsch'),
('Die unendliche Geschichte', 'Thienemann', 1979, 'Deutsch');

SELECT * FROM Book;

INSERT INTO BookAuthor (book_id, author_id) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5),
(6, 6),
(7, 7),
(8, 8),
(9, 9),
(10, 10);

SELECT * FROM BookAuthor;

INSERT INTO BookGenre (book_id, genre_id) VALUES
(1, 1),
(2, 2),
(3, 2),
(4, 3),
(5, 4),
(6, 4),
(7, 5),
(8, 6),
(9, 9),
(10, 2);

SELECT * FROM BookGenre;

INSERT INTO BookCopy
(book_id, owner_id, `condition`, max_loan_days, shipping)
VALUES
(1, 1, 'Sehr gut', 14, 1),
(2, 2, 'Gut', 21, 0),
(3, 3, 'Gut', 14, 1),
(4, 4, 'Gebraucht', 30, 0),
(5, 5, 'Sehr gut', 14, 1),
(6, 6, 'Gebraucht', 21, 0),
(7, 7, 'Gut', 14, 1),
(8, 8, 'Sehr gut', 30, 1),
(9, 9, 'Gut', 14, 0),
(10, 10, 'Sehr gut', 21, 1);

SELECT * FROM BookCopy;

INSERT INTO PickupLocation (copy_id, address_id) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5),
(6, 6),
(7, 7),
(8, 8),
(9, 9),
(10, 10);

SELECT * FROM PickupLocation;

INSERT INTO TimeSlot (location_id, `date`, start_time, end_time) VALUES
(1, '2026-10-01', '16:00:00', '18:00:00'),
(2, '2026-10-02', '17:00:00', '19:00:00'),
(3, '2026-10-03', '10:00:00', '12:00:00'),
(4, '2026-10-04', '14:00:00', '16:00:00'),
(5, '2026-10-05', '18:00:00', '20:00:00'),
(6, '2026-10-06', '15:00:00', '17:00:00'),
(7, '2026-10-07', '16:30:00', '18:30:00'),
(8, '2026-10-08', '17:30:00', '19:30:00'),
(9, '2026-10-09', '11:00:00', '13:00:00'),
(10, '2026-10-10', '14:30:00', '16:30:00');

SELECT * FROM TimeSlot;

INSERT INTO Loan
(copy_id, loan_date, due_date, return_date, borrower_id) VALUES
(1, '2026-08-01', '2026-08-15', '2026-08-14', 2),
(2, '2026-08-03', '2026-08-24', '2026-08-22', 3),
(3, '2026-08-05', '2026-08-19', '2026-08-19', 4),
(4, '2026-08-07', '2026-09-06', '2026-09-03', 5),
(5, '2026-08-10', '2026-08-24', '2026-08-23', 6),
(6, '2026-08-12', '2026-09-02', '2026-08-30', 7),
(7, '2026-08-15', '2026-08-29', '2026-08-28', 8),
(8, '2026-08-18', '2026-09-17', '2026-09-15', 9),
(9, '2026-08-20', '2026-09-03', '2026-09-02', 10),
(10, '2026-08-22', '2026-09-12', '2026-09-10', 1);

SELECT * FROM Loan;

INSERT INTO Review
(book_id, user_id, rating, comment) VALUES
(1, 2, 5, 'Sehr spannendes Buch'),
(2, 3, 5, 'Hat mir sehr gut gefallen'),
(3, 4, 4, 'Spannende Geschichte'),
(4, 5, 4, 'Sehr spannend geschrieben'),
(5, 6, 4, 'Interessanter Klassiker'),
(6, 7, 5, 'Kurze und interessante Geschichte'),
(7, 8, 4, 'Sehr lesenswert'),
(8, 9, 5, 'Spannender Krimi'),
(9, 10, 4, 'Unterhaltsames Buch'), 
(10, 1, 5, 'Sehr fantasievolle Geschichte');

SELECT * FROM Review;

SELECT
    Book.title,
    Author.name AS author
FROM Book
JOIN BookAuthor
    ON Book.book_id = BookAuthor.book_id
JOIN Author
    ON BookAuthor.author_id = Author.author_id;
    
SELECT
    Book.title,
    Genre.name AS genre
FROM Book
JOIN BookGenre
    ON Book.book_id = BookGenre.book_id
JOIN Genre
    ON BookGenre.genre_id = Genre.genre_id;
    
SELECT
    `User`.name AS borrower,
    BookCopy.copy_id
FROM `User`
JOIN Loan
    ON `User`.user_id = Loan.borrower_id
JOIN BookCopy
    ON Loan.copy_id = BookCopy.copy_id;
    
SELECT
    Book.title,
    Author.name AS author
FROM Book
JOIN BookAuthor
    ON Book.book_id = BookAuthor.book_id
JOIN Author
    ON BookAuthor.author_id = Author.author_id;