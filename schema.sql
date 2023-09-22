/*Put your CREATE TABLE statements (and any other schema related definitions) here*/
DROP TABLE IF EXISTS Act CASCADE;
DROP TABLE IF EXISTS gig CASCADE;
DROP TABLE IF EXISTS act_gig CASCADE;
DROP TABLE IF EXISTS venue CASCADE;
DROP TABLE IF EXISTS gig_ticket CASCADE;
DROP TABLE IF EXISTS ticket CASCADE;



CREATE TABLE Act(
    actID SERIAL PRIMARY KEY,
    actname VARCHAR(100) UNIQUE ,
    genre VARCHAR(10) NOT NULL ,
    standardfee INT CONSTRAINT nonnegative_price CHECK (standardfee > 0)
);

CREATE TABLE venue (
    venueid SERIAL PRIMARY KEY,
    venuename VARCHAR(100) NOT NULL UNIQUE ,
    hirecost INT CONSTRAINT nonnegative_hirecost CHECK (hirecost > 0),
    capacity INT
);

CREATE TABLE gig(
    gigID SERIAL PRIMARY KEY,
    venueid INT REFERENCES venue(venueid),
    gigtitle VARCHAR(100),
    gigdate TIMESTAMP,
    gigstatus VARCHAR(10)  DEFAULT 'GoingAhead'
);

CREATE TABLE act_gig(
    actID INT REFERENCES Act(actID),
    gigID INT REFERENCES gig(gigID),
    actfee INT CONSTRAINT positive_fee CHECK (actfee > 0),
    ontime TIMESTAMP,
    duration INT CONSTRAINT positive_duration CHECK (duration > 0),
    PRIMARY KEY(actID,gigID,ontime)
);


CREATE TABLE gig_ticket(
    gigID INT REFERENCES gig(gigID),
    pricetype VARCHAR(2),
    price INT CHECK (price >= 0),
    CONSTRAINT one_pricetype_per_gigID Unique(gigID,pricetype)
);

CREATE TABLE ticket(
    ticketid SERIAL PRIMARY KEY,
    gigID INT REFERENCES gig(gigID),
    CustomerName VARCHAR(100) ,
    CustomerEmail VARCHAR(100),
    pricetype VARCHAR(2),
    Cost INT
);
 


CREATE TRIGGER NewAct_gig BEFORE INSERT ON act_gig
FOR EACH ROW
EXECUTE PROCEDURE insertAct_gig();

CREATE TRIGGER RemoveAct BEFORE DELETE ON act_gig
FOR EACH ROW
EXECUTE PROCEDURE beforedeleteAct_gig();


CREATE TRIGGER NewGig_ticket BEFORE INSERT ON gig_ticket
FOR EACH ROW
EXECUTE PROCEDURE insertGig_ticket();

CREATE TRIGGER NewTicket BEFORE INSERT ON ticket
FOR EACH ROW
EXECUTE PROCEDURE insertTicket();

----------------

-- This query is a view that calculates the total cost of each gig.
-- The first table is a table that calculates the cost of the venue for each gig.
-- The second table is a table that calculates the total cost of all the acts of each gig.
-- The third table is a table that joins the first two tables and adds the cost of the venue and the cost of the acts for each gig.
-- The third table is the view that is created.

-- The first table is created by joining the gig and venue tables using the venueid.
-- The second table is created by grouping the act_gig table by gigID and summing the actfee for each gig.
-- The third table is created by joining the first two tables using the gigID.
-- The third table is the view that is created.

-- The COALESCE function is used to replace NULL values with 0.
-- This is in case the venue cost for a gig is be NULL and the act cost for a gig is NULL.
-- If the venue cost is NULL and the act cost is NULL, the total cost of the gig will be NULL.
CREATE VIEW expenses AS WITH table1 AS ( SELECT gigID, hirecost a FROM gig JOIN venue USING(venueid) 
--then selecting the total cost of all the acts of each gig
), table2 AS( SELECT gigID, SUM(actfee) b FROM act_gig GROUP BY gigID 
--and addidng these two type of cost for each gig by joining these tables
)   SELECT gigID,  COALESCE(a,0) + COALESCE(b,0) as Expenditures FROM table1 JOIN table2 USING(gigID);


-- View called sales:
-- Select the gigID and the sum of the cost of all tickets for that gigID
-- Group the results by gigID
CREATE VIEW sales AS (SELECT gigID, SUM(Cost) Profits FROM ticket GROUP BY gigID);

--All the last acts for every gig
CREATE VIEW lastacts AS( SELECT gigID,actID,ontime,duration,actfee From ( SELECT Row_Number() OVER(PARTITION BY gigID ORDER BY ontime DESC)AS 
    row_number, * FROM act_gig) AS a WHERE a.row_number = 1);
--These are the headlines, i.e the last acts from all the not cancelled gigs
CREATE VIEW headlines AS(SELECT gigID,actID,ontime,actname FROM (lastacts l JOIN gig g USING(gigID) )JOIN act a USING(actID) WHERE g.gigstatus='GoingAhead');

--This view is created to help me with option 6. It is a partition on the actIDS
-- CREATE VIEW partition1 AS (SELECT row_number, gigID,actID,actname, to_char(date, 'yyyy')as year FROM( SELECT Row_Number() over(partition by actID)as 
--     row_number,ontime::date AS date, * FROM  headlines h join ticket t using(gigID)as g) as d );

-- CREATE VIEW partition2 AS WITH totals AS( SELECT actID, COUNT(*) as total FROM headlines h join ticket t using(gigID)as g GROUP BY actID)
-- SELECT  gigID,actID,actname, to_char(ontime::date, 'yyyy')as year, total FROM  (headlines h join ticket t using(gigID)as g ) JOIN totals USING(actID) ORDER BY total,actname asc;


------------------------------
--VIEW CREATED FOR OPTION 6
-- The this view is created to give direct results to what is wanted
-- for this option. It is a combination of two sub queries in option 6 and option 6a.
-- The first part of the query is a CTE (Common Table Expression) which is a temporary table that is created and used in the same query.
-- The CTE is used to create a table called partition1 which contains the actname, gigID, actID and year of the gig.
-- The second CTE is used to create a table called totals which contains the actname and the total number of gigs they have played.
-- The final part of the query is a UNION of two SELECT statements.
-- The first SELECT statement is used to create a table called l which contains the actname, year and the number of gigs they played in that year.
-- The second SELECT statement is used to create a table called option6a which contains the actname, year, number of gigs and total number of gigs.
-- The final SELECT statement is used to create a table called option6 which contains the actname, year, number of gigs and total number of gigs.
-- The final SELECT statement is a UNION of the table l and the table option6a to add the total row at the end of each act.
-- The table l is joined to the table totals using the actname.
-- The table option6a is not joined to any other table
CREATE VIEW option6a AS( SELECT actname,'Total' as year, COUNT(*) as count, COUNT(*) as total FROM headlines h join ticket t using(gigID)as g GROUP BY actname);

CREATE VIEW option6 AS WITH partition1  AS (SELECT  gigID,actID,actname, to_char(ontime::date, 'yyyy')as year FROM  (headlines h join ticket t using(gigID)as g )),
totals AS( SELECT actname, COUNT(*) as total FROM headlines h join ticket t using(gigID)as g GROUP BY actname)
SELECT * FROM (select actname,year,COUNT(actid) from partition1 GROUP BY actname,year) l JOIN totals t USING(actname) UNION SELECT * FROM option6a ORDER BY total,actname,year asc;


--option7
--Please view Readme file for thoughly explanation on this
CREATE VIEW option7a AS SELECT gigID,CustomerName,CustomerEmail,COUNT(gigID) as ticketAmount 
FROM ticket GROUP BY (CustomerEmail,gigID,CustomerName);
CREATE VIEW option7b AS SELECT gigid,actid,to_char(ontime::date,'yyyy') as year,actname 
FROM headlines;
CREATE VIEW option7c AS SELECT * FROM option7a a RIGHT JOIN option7b b USING(gigID) order by actname;
CREATE VIEW option7d AS SELECT actid,COUNT(DISTINCT(actid,year)) AS number_of_years FROM option7b GROUP BY(actid);
CREATE VIEW option7e AS SELECT actID,CustomerEmail,SUM(ticketamount) as total_tickets_for_act FROM option7c GROUP BY(CustomerEmail,actID);
CREATE VIEW option7f AS SELECT * FROM option7c c LEFT JOIN option7d d USING(actID) LEFT JOIN OPTION7e e USING(actID,CustomerEmail);
CREATE VIEW option7g AS SELECT * FROM option7f f LEFT JOIN (SELECT CustomerEmail,actID,COUNT(CustomerEmail) AS years_attended 
FROM option7c GROUP BY CustomerEmail,CustomerName,actID) n USING(CustomerEmail,actID);
CREATE VIEW option7 AS SELECT actname,CASE WHEN CustomerName IS NULL THEN '[None]' ELSE CustomerName END FROM (
    SELECT DISTINCT CustomerEmail,CustomerName,actname,number_of_years,total_tickets_for_act,years_attended FROM option7g 
    WHERE number_of_years=years_attended OR years_attended is NULL ORDER BY actname ASC, total_tickets_for_act DESC) a;

---------

CREATE VIEW option8 AS SELECT venuename,actname,ticket_number FROM (
    SELECT *,tickets_required(standardfee,hirecost,capacity) as ticket_number FROM act a CROSS JOIN venue v ) table1 
    WHERE ticket_number>0 ORDER BY venuename ASC, ticket_number DESC;



--------------------------------------------------------

CREATE OR REPLACE FUNCTION insertAct_gig() RETURNS trigger AS $$
    DECLARE
        datevar TIMESTAMP;
        thisvenue INT;
        c INT;
        c2 INT;
    BEGIN
       SELECT gigdate FROM gig INTO datevar WHERE gigID=NEW.gigID;
        SELECT venueid FROM gig g INTO thisvenue WHERE g.gigID=NEW.gigID;
        IF NEW.ontime<datevar THEN
            RAISE NOTICE 'The ontime must be must be on or after the gigs gigdate on %', datevar;
            RETURN NULL;
        END IF;
        --Check if the gig starts and finishes the same date
        IF (NEW.ontime+ (INTERVAL '1 min' * NEW.duration))::date<>NEW.ontime::date THEN
            RAISE NOTICE 'Gig should not go beyond 11:59pm';
            RETURN NULL;
        END IF;
        --Check if the new act overlaps with other acts on the gig
        SELECT COUNT(*) FROM act_gig ag  LEFT JOIN gig g USING (gigID) INTO c WHERE NEW.gigID=ag.gigID AND g.gigstatus<>'Cancelled' AND ((NEW.ontime,INTERVAL '1 min' * NEW.duration) OVERLAPS (ag.ontime,INTERVAL '1 min' * ag.duration));
        IF c>0 THEN
            RAISE NOTICE 'Act clashes with another act of the same gig';
            RETURN NULL;
        END IF;
        --Check if new act is in more than one gigs at the same time
        SELECT COUNT(*) FROM act_gig ag JOIN gig g USING(gigID) INTO c2 WHERE ag.actID=NEW.actID AND (
        (g.venueid<>thisvenue AND ((NEW.ontime,INTERVAL '1 min' * NEW.duration + interval '20 minutes') OVERLAPS (ag.ontime,INTERVAL '1 min' * ag.duration + interval '20 minutes')))
        OR (g.venueid=thisvenue AND ((NEW.ontime,INTERVAL '1 min' * NEW.duration) OVERLAPS (ag.ontime,INTERVAL '1 min' * ag.duration))) ); --Checks that each an act has 20 mins interval between gigs on different venues
        IF c2>0 THEN
            RAISE NOTICE 'Make sure an Act does not overlap with itself (must exists >20mins difference from its finish time it it performs on different venue)';
            RETURN NULL;
        END IF;
        /*If the execution reaches this far, we must be OK to insert the row, so return NEW*/
        RETURN NEW;
    END;
    $$ language plpgsql; 


-- -------------------------------------
CREATE OR REPLACE FUNCTION insertGig_ticket() RETURNS trigger 
language plpgsql
AS $$
    DECLARE
        c INT;
        latestact TIMESTAMP;
    BEGIN

        SELECT (ontime+INTERVAL '1min'*COALESCE(duration,0))::TIMESTAMP  FROM act_gig  ag INTO latestact WHERE ag.gigID=NEW.gigID ORDER BY ag.ontime DESC LIMIT 1;
        
        WITH gig1 AS(SELECT * FROM gig WHERE gigID=NEW.gigID LIMIT 1),
        table1 AS(
        --finds the gigs that take place in the same venue the same date as the inserted gig
        SELECT g2.gigID FROM gig g2, gig1 g1 WHERE g2.gigID<>g1.gigID AND g2.venueid=g1.venueid AND g2.gigdate::date= g1.gigdate::date AND g2.gigstatus='GoingAhead'),
        --Finds the latest act of each one of those gigs
        checktable AS(SELECT gigID,gigdate,finishtime FROM(SELECT gigID,  MAX(ontime+INTERVAL '1min'*COALESCE(duration,0))::TIMESTAMP AS finishtime FROM act_gig ag2 WHERE ag2.gigID IN (SELECT gigID FROM table1) GROUP BY gigID) a JOIN gig USING(gigID))
        --Finds the last act of each one of those gigs
        --If a gig has no acts then no need to be considered
        --in order to make sure that there is no 3 hour overlap
        SELECT COUNT(*) FROM  checktable t ,gig1 INTO c WHERE  ((gig1.gigdate,(latestact +INTERVAL '3 hours')::TIMESTAMP) OVERLAPS (t.gigdate,(t.finishtime+INTERVAL '3 hours')::TIMESTAMP));
        IF c>0 THEN
            RAISE NOTICE 'Gig must be within 3 hours of interval between other gigs on the same venue';
            RETURN NULL;
        END IF;

        --Checking that all acts in a gig have no more than 20 min difference
        WITH tempTable AS(
        --
        SELECT *,ROW_NUMBER() OVER(ORDER BY ontime ASC) AS r FROM act_gig g WHERE g.gigID=NEW.gigID )
        
        SELECT COUNT(*)  FROM tempTable t1, tempTable t2 INTO c WHERE  t1.r=t2.r-1 AND NOT ((getOffTime(t1.ontime,t1.duration), INTERVAL '20 min' ) OVERLAPS (t2.ontime,INTERVAL '1 min' *t2.duration));
        IF c>0 THEN
            RAISE NOTICE 'Acts must have no more than 20 mins space in a gig';
            RETURN NULL;
        END IF;
        /*If the execution reaches this far, we must be OK to insert the row, so return NEW*/
        RETURN NEW;
    END;
$$ ;   

----------------------------------
--Function called to check constraints on newly inserted entry of ticket relation
    CREATE OR REPLACE FUNCTION insertTicket() RETURNS trigger AS $$
    DECLARE
        isvalid BOOLEAN;
        count1 INT;
        count2 INT;
        gstatus VARCHAR;
    BEGIN
        --Make sure that the gigID exists
        IF NOT EXISTS(SELECT 1 FROM gig WHERE gigID=NEW.gigID) THEN
            RAISE NOTICE 'Gig ID entered does not exist';
            RETURN NULL;
        END IF;
        SELECT gigstatus FROM gig INTO gstatus WHERE gigID=NEW.gigID ;
        IF (gstatus='CANCELLLED') THEN
            RAISE NOTICE 'Gig is cancelled';
            RETURN NULL;
        END IF;
        --Checking if the inserted pricetype is a pricetype of the gig
        IF NEW.pricetype NOT IN (SELECT pricetype FROM gig_ticket WHERE gigID=NEW.gigID) THEN
            RAISE NOTICE 'Pricetype Entered cannot be matched';
            RETURN NULL;
        END IF;
    
        --find the number of tickets sold so far for the given gig
        SELECT COUNT(*) FROM ticket t INTO count1 WHERE t.gigID=NEW.gigID;
        --find the capacity of the venue of the gig
        SELECT COALESCE(capacity,0) FROM venue v JOIN gig g USING(venueid) INTO count2 WHERE g.gigID=NEW.gigID;
        --check if there are still available tickets given the capacity
        IF count2-count1<=0 THEN
            RAISE NOTICE 'SOLD OUT';
            RETURN NULL;
        END IF;
        
        /*If the execution reaches this far, we must be OK to insert the row, so return NEW*/
        RETURN NEW;
    END;
    $$ language plpgsql;  
    
----------------------------------
--Used in Option 4. Triggered before deleting an act from a gig
    CREATE OR REPLACE FUNCTION beforedeleteAct_gig() RETURNS trigger AS $$
    DECLARE
       c INT;
       oldID INT;
    BEGIN
        SELECT OLD.gigID INTO oldID;
    

       --The act right before the Deleted act in the gig
        WITH table1 AS(SELECT * FROM act_gig WHERE gigID=OLD.gigID AND ontime<OLD.ontime ORDER BY ontime DESC LIMIT 1),
        --the act right after the Deleted act in the gig
        table2 AS (SELECT * FROM act_gig WHERE gigID=OLD.gigID AND ontime>OLD.ontime ORDER BY ontime ASC LIMIT 1)
        
        SELECT COUNT(*) FROM table1 t1, table2 t2 INTO c WHERE (t1.actID=t2.actID) OR  NOT ((getOffTime(t1.ontime,t1.duration), INTERVAL '20 min' ) OVERLAPS (t2.ontime,INTERVAL '1 min' *t2.duration));
        --In case there is no act after(headline) or there is no act before(first act-meaning that it will violate start time constraint) OR it creates an interval larger than 20mins between acts
        IF c>0 OR (SELECT actID FROM act_gig WHERE gigID=OLD.gigID AND ontime<OLD.ontime ORDER BY ontime DESC LIMIT 1) IS NULL OR 
        (SELECT actID FROM act_gig WHERE gigID=OLD.gigID AND ontime>OLD.ontime ORDER BY ontime ASC LIMIT 1) IS NULL THEN
            RAISE NOTICE 'THE ENTIRE GIG NEEDS TO BE CANCELLED DUE TO CONSTRAINT VIOLATION';
            UPDATE gig SET gigstatus='Cancelled' WHERE gigID=OLD.gigID;
            UPDATE ticket SET Cost=0 WHERE gigID=OLD.gigID;
        END IF;
        /*If the execution reaches this far, we must be OK to insert the row, so return NEW*/
        RETURN OLD;
    END;
    $$ language plpgsql; 

    CREATE OR REPLACE PROCEDURE deleteAct_gig(deletedGigID INT,deletedActName VARCHAR)
    LANGUAGE plpgsql AS
    $$
    DECLARE
    act_id INT;
    BEGIN
        SELECT actID FROM act INTO act_id WHERE actname=deletedActName;
        DELETE FROM act_gig ag WHERE ag.gigID=deletedGigID AND ag.actID=act_id;
        commit; 
    END
    $$;


----------------------------------
-- We get the ontime and duration as parameters
-- Returns the finish time
    CREATE OR REPLACE FUNCTION getOffTime(ontime TIMESTAMP, duration INT )
    returns TIMESTAMP
    LANGUAGE plpgsql
    AS
    $$
        DECLARE
            offtime TIMESTAMP;
        BEGIN
            /*Result is a new timestamp of the offtime*/
            --Adding in the offtime the duration casted as Interval in minutes
            SELECT ontime+(INTERVAL '1 min' * duration) INTO offtime;
            RETURN offtime;
        END;
    $$;


    --The number of tickes that need to be sold is how many times we need to multiply 
    --the average ticket cost to get a number equal or the extact next to the hirecost 
    --plus the standard fee that are the two expenses we want to balance. If the number of tickets
    --needed exceeds the capacity then return 0 as an indication that it is not possible
    CREATE OR REPLACE FUNCTION tickets_required( standardfee INT,hirecost INT, capacity INT)
    returns INT
    LANGUAGE plpgsql
    AS
    $$
        DECLARE
            meanPrice DECIMAL;
            ticketNumber INT;
        BEGIN
        --Finds the average price of all tickets from non Cancelled gigs

            WITH cancelledGigs AS(SELECT * FROM gig g WHERE g.gigstatus='CANCELLED'),
             not_cancelled_ticked AS (SELECT Cost FROM ticket t WHERE t.gigID NOT IN (SELECT gigID FROM cancelledGigs))
            SELECT AVG(Cost) FROM not_cancelled_ticked INTO meanPrice;
        --Finds finds the number of tickets that need to be sold 
            SELECT ceiling((hirecost+standardfee)::double precision /meanPrice::double precision)::INT INTO ticketNumber;
            IF ticketNumber<=capacity THEN
                RETURN ticketNumber;
            ELSE
                RETURN 0;
            END IF;
        END;
    $$;

-- ---------------------------------------
-- --Procedure for adding more domain to the PriceType Data Type
-- --USE CALL insert_new_ticket_type('d');
-- -- CREATE OR REPLACE PROCEDURE insert_new_tick
-- -------------------------------------------------------- 
