-- A
DROP TABLE IF EXISTS votes;
DROP TABLE IF EXISTS running;
DROP TABLE IF EXISTS party;
DROP TABLE IF EXISTS election;
DROP TABLE IF EXISTS city;

CREATE TABLE election
(
    edate DATE,
    kno INT,
    PRIMARY KEY (edate)
);

CREATE TABLE party
(
    pname CHAR(20),
    symbol CHAR(5),
    PRIMARY KEY (pname)
);

CREATE TABLE running
(
    edate DATE,
    pname CHAR(20),
    chid NUMERIC(5, 0),
    totalvotes INT DEFAULT 0,
    PRIMARY KEY (edate, pname),
    FOREIGN KEY (edate) REFERENCES election,
    FOREIGN KEY (pname) REFERENCES party
);

CREATE TABLE city
(
    cid NUMERIC(5, 0),
    cname VARCHAR(20),
    region VARCHAR(20),
    PRIMARY KEY (cid)
);

CREATE TABLE votes
(
    cid NUMERIC(5, 0),
    edate DATE,
    pname CHAR(20),
    nofvotes INT NOT NULL,
    PRIMARY KEY (cid, pname, edate),
    FOREIGN KEY (edate) REFERENCES election,
    FOREIGN KEY (pname) REFERENCES party,
    FOREIGN KEY (cid) REFERENCES city,
    FOREIGN KEY (edate, pname) REFERENCES running(edate, pname)
);

-- B
CREATE OR REPLACE FUNCTION trigf1() RETURNS TRIGGER AS $$
BEGIN
    UPDATE running 
    SET totalvotes = totalvotes + NEW.nofvotes - 
                    CASE WHEN OLD.nofvotes IS NOT NULL THEN OLD.nofvotes ELSE 0 END
    WHERE running.edate = NEW.edate AND running.pname = NEW.pname;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER T1 
AFTER INSERT OR UPDATE ON votes
FOR EACH ROW 
EXECUTE PROCEDURE trigf1();

-- C
INSERT INTO election 
VALUES
    ('2019-04-09', 1),
    ('2019-09-17', 2),
    ('2020-03-02', 3),
    ('2021-03-23', 4),
    ('2022-11-01', 5);

INSERT INTO party 
VALUES
    ('nature party', 'np'),
    ('science group', 'sg'),
    ('life party', 'lp'),
    ('art group', 'ag'),
    ('lost group', 'lg');

INSERT INTO city 
VALUES
	(22, 'ryde end', 'north'),
    (77, 'east strat', 'south'),
    (33, 'grandetu', 'center'),
    (88, 'royalpre', 'hills'),
    (11, 'carlpa', 'hills'),
    (44, 'lommont', 'north'),
    (66, 'grand sen', 'south'),
    (99, 'kingo haven', 'hills'),
    (55, 'el munds', 'south');

INSERT INTO running 
VALUES
    ('2019-04-09', 'nature party', 12345),
    ('2019-04-09', 'life party', 54321),
    ('2019-04-09', 'lost group', 34567),
    ('2019-09-17', 'lost group', 76543),
    ('2019-09-17', 'art group', 67890),
    ('2020-03-02', 'science group', 90876),
    ('2020-03-02', 'nature party', 55555),
    ('2020-03-02', 'life party', 54321);

INSERT INTO votes 
VALUES
    (22, '2020-03-02', 'nature party', 100),
    (22, '2020-03-02', 'science group', 30),
    (22, '2020-03-02', 'life party', 500),
    (77, '2020-03-02', 'nature party', 300),
    (77, '2020-03-02', 'science group', 150),
    (77, '2020-03-02', 'life party', 25),
    (33, '2020-03-02', 'nature party', 13),
    (33, '2020-03-02', 'science group', 740),
    (33, '2020-03-02', 'life party', 670);


--d1
SELECT pname, nofvotes
FROM votes NATURAL JOIN city
WHERE cname = 'ryde end' AND edate = '2.3.2020' AND nofvotes <> 0;


--d2
SELECT pname, region, SUM(nofvotes) AS total_in_region
FROM election NATURAL JOIN votes NATURAL JOIN city
WHERE kno = 3
GROUP BY region, pname;

--d3
SELECT cname, region
FROM city
WHERE cid NOT IN (
    SELECT cid
    FROM votes
    WHERE pname = 'life party'
);


--d4
SELECT DISTINCT edate, kno
FROM election NATURAL JOIN running
WHERE kno IN (
    SELECT kno
    FROM election NATURAL JOIN running
    GROUP BY kno
    HAVING COUNT(pname) >= ALL (
        SELECT COUNT(pname)
        FROM election NATURAL JOIN running
        GROUP BY kno
    )
);

--d5
SELECT pname
FROM running
WHERE pname IN (
    SELECT pname
    FROM election NATURAL JOIN running
    WHERE kno = 3 AND pname NOT IN (
        SELECT pname
        FROM votes NATURAL JOIN city
        WHERE region = 'hills'
    )
    GROUP BY pname
    HAVING SUM(totalvotes) <= ALL (
        SELECT SUM(totalvotes)
        FROM running
        WHERE pname IN (
            SELECT pname
            FROM election NATURAL JOIN running
            WHERE kno = 3 AND pname NOT IN (
                SELECT pname
                FROM votes NATURAL JOIN city
                WHERE region = 'hills'
            )
            GROUP BY pname
        )
    )
);



--d6
SELECT pname
FROM running NATURAL JOIN election
WHERE kno = 3 AND totalvotes = (
    SELECT MAX(totalvotes)
    FROM running NATURAL JOIN election
    WHERE kno = 3 AND totalvotes < ALL (
        SELECT MAX(totalvotes)
        FROM running NATURAL JOIN election
        WHERE kno = 3
    )
);

--d7

SELECT DISTINCT p1.pname AS party_1, p2.pname AS party_2
FROM running AS p1, running AS p2
WHERE p1.pname < p2.pname AND p1.edate = p2.edate
    AND p1.pname NOT IN (
        SELECT DISTINCT r1.pname
        FROM running AS r1
        WHERE r1.edate NOT IN (
            SELECT r2.edate
            FROM running r2
            WHERE r2.pname = p2.pname
        )
    )
    AND p2.pname NOT IN (
        SELECT DISTINCT r1.pname
        FROM running r1
        WHERE r1.edate NOT IN (
            SELECT DISTINCT r2.edate
            FROM running r2
            WHERE r2.pname = p1.pname
        )
    );