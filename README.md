
#Design Choices
In order to improve our table structure, we need to follow data Normalisation with these goals in mind:
1. Remove repeating groups
2. Remove redundant data
3. Remove columns not dependent on key
The current relationship schemas must be decomposed into smaller relation schemas.
Staring from the ‘ticket’ table. We can create a new table that we can name ‘Customer’, in which we store the CustomerName and CustomerEmail. These two attributes are not in the same group as the ticket details. We can connect each Customer with the tickets bought by using as foreign key the generated primary key from the ‘Customer’ table.

For every relation that has foreign key we can create a new relation that stores the primary keys of the two relations and remove the foreign key. Creating relations venue_ticket, gig_venue like this:

CREATE TABLE venue_ticket(
    venueid INT REFERENCES venue(venueid),
    ticketid INT REFERENCES ticket(ticketid),
    PRIMARY KEY(venueid,ticketid)
);

Also to make sure there are no anomalies within the schema, for VARCHAR attributes like genre and pricetype that we have an expectation of what will be inserted, we can restrict the domain. This can be done by using ENUM types where the inserted record must be the exact same as one of the listed values of the ENUM. Or we can create a new relation, e.g. ‘genre’ that stores different genres along a primary key that is a foreign key in the relation we want to use them. What we truly achieve? We don’t end up in citations where one entry has genre ‘rock’ and another that has ‘ROcK’ .
##ENUM example
CREATE TYPE cstatus AS ENUM ('Cancelled', 'GoingAhead');
CREATE TYPE Ttype AS ENUM ('A', 'O', 'F');
##New relation example
genre_id | genre
_______ |_________
1             | ‘pop’
2             | ‘rock’



#Option 1

In this part we need to use a query to get the wanted results.
We are given a gigID as parameter and we want to return actName, ontime and
offtime. The act name only exists in the act table. So in the query we use the gigID to get the actIDs from the act_gig table that is primary key in the act table(so we can get the actName). The onetime we get it from the same query on the act_gig table search for entries that match the gigID parameter. For the offtime I created an sql function that is called which takes the ontime and the duration(already in act_gig) and it calculates and returns the offtime.

#Option 2
In this option we want to insert a gig with its corresponding acts. It is really important that if any constraint is not satisfied at any stage of inserting an entry of the given data, to cancel the whole process and rollback the state of the database. So to do that we first turn off the autommit. Before inserting the Gig we query to find the venueID of the inserted venueName. Given that it exist we then insert the Gig. After the gig is inserted successfully instead of querying again to get the newly generated gigID for that gig, we use the Statement.RETURN_GENERATED_KEYS to get in a ResultSet the new gigID. And so now we insert the act_gigs by looping through the elements of the parallel arrays. At last we insert the ticket that corresponds to the adultprice ‘A’ for the new gigID  that we got earlier.
In case one of the inserts fails or a query fails I use the rollback and cancel the whole insertion. 
All the constraints of the database updates  from this method are checked using triggers. When the gig is inserted except from checking about its gigStatus we still don’t check on other constraints. The reason is because we wait until all the act_gigs are inserted and then do further checks on the gig.
Before every act_gig that is inserted it checks that its ontime is not before the gig’s start time, and makes sure that it doesn’t finish after midnight  and it doesn’t overlap with other acts of the same gig but also that it doesn’t overlap with itself, including  the 20 extra mins check when it performs in another venue.
Finally, the most important part is the trigger that calls the function insertGig_ticket() right before the gig_ticket is inserted. For the new gig_ticket we don’t check anything since they are values that have been checked. But this is the right opportunity to check for the constraints that we can’t check unless all acts of a gig to be inserted first. 
We check that the new gig is has 3 hours space before and after every other gig on the same venue, on the same date. Method: Find all gigs on the same date, on the same venue. Create a new column along those gigs that is the time the last act finishes and find whether at least one of these gigs has start time  and finish time that overlaps the start time and finish time of new gig, plus 3 hours.
 If the check was successful, we then order all the acts of the new gig by ontime,  and check to find two consecutive acts have time interval larger than 20 minutes between. If none found then it means that there is no constraint violation, therefore on the Java program we use the commit() command, otherwise(o/w) we use the rollback to undo all the changes.

#Option 3
We issue a query to find the matching price of the gigID and pricetype arguments. We use the price in the update statement to insert the new ticket. Before the ticket is inserted the trigger function  insertTicket() is called to check that the gigID exists, that the gig is not Cancelled and that the gig is not Sold out(comparing the number of tickets already bought with the capacity of the venue)

#Option 4
We use a call to the deleteAct_gig() procedure to delete the act from a specific gig.
In this procedure we first find the actID and use along with the gigID it to delete all the matching act_gigs. In doing so we have created a trigger beforedeleteAct_gig() which will check whether the whole gig needs to be cancelled. To do that we find the two acts, the one after and the one before the deleted one. If one of these is null it means that our gig will be cancelled because it is either the last act(headline) or it is the first act which means that it will violate the start time constraint of the gig. With these two we use a them in a query with a COUNT(*) where if satisfied the count will become 1, o/w it will be 0. This query checks whether they have the same actID, which will violate the constraint that there shouldn’t be one act performing back to back and also it checks if the maximum interval of 20’ mins between acts is violated. In the case of  such constraint violation then we update the table to indicate that the gig is cancelled. Set gigstatus to ‘CANCELLED’ and the the cost of all the gig tickets to 0.
Now returning in the method in Java we have to return the email addresses of the who had tickets for the gig, but only if it was cancelled . To do this we use a query to select distinct email addresses from the ticket table with the given gigID, but only if the gigstatus is ‘Cancelled’. Because the gigstatus is only in the gig table we join the gigtable with the ticket table just to check this value.
After that we return the emails as a String[ ], or if the gig was not cancelled we return null.

#Option 5
For these option we created two views. One View, the expenses  , were we calculate all the expenses of a gig by using the aggregate sum() to get the sum all the fees of the acts acts for the gig, and we add that to the hirecost of the venue of the gig. Because we want this for every gig we use JOIN between these two using the gigID. The second View is the sum of all the tickets sold so far for every gig. 
We use these two views by subtracting their two sums for each gig to get the balance. Since we want every gigID (no matter if they have null expenses or null sales) to be include we also use the full outer join in this query.
We calculating the amount of tickets by dividing with the price of the ticket with pricetype ‘A’, for the corresponding gig. It should be noted that we use constraint on the query that if there is no ‘A’ for that gig , or if the price for ‘A’ zero, which both can cause exceptions , so we eliminate the specific gig from showing up

#Option 6
We multiple common table expressions(CTE), i.e. temporary tables in this query.
##partition1: creates a table which gathers information about the gigID, actID, actName and a year column( which is extracted from the timestamp of ontime and is converted to string) for all the headlines that are already calculated by the headline view(which already filters out the gigs that are cancelled).
##totals: creates a table with a column that has the number of headlines of each distinct act
##view option6a: Is a view that is created for the total row of each act. It has the same column twice so that we can use Union with the main view.
##view option6: At the end it joins the partition1 with the totals and adds the option6a using UNION. The data are all sorted using the extra column , totals , that we won’t need in the final result. Which is why in the query in java we only select actname, year and count.


#Option 7
In this option the java query is very simple since we just select everything from the view option7. But, option7 uses many other views to present the final result.
##option7a: to get the amount of tickets that each customer bought for a gig
##option7c: Uses the information gathered in option 7a and adds it as extra columns on the columns from the headlines view that were gathered in option7b.
##option7e: Uses grouping on email and actID on the view option7c to get the total tickets that each customer bough for each act. 
##option7f: Joins the previous two options plus the option option7d which calculates the number of years an act was a headline. So In option7f we get a large table and we make sure to sure Left Join in order to not loose records.
##option7f: We add another column from Join by selecting count from grouping by customer emails and  acts on option7c. This new count column is the number of years that a specific customer has the specific gig when it was headline.
##option7: Here we select only the rows that the number of years of attendance is the same as the number_of_years which is the number of years that the act was headline , or select the null which indicates that such a customer does not exist, but we still want to represent. We also order by actname ascending  and the total tickets per act descending. In the final query we select only the actname and customer email and also specify that we want Null to be represented by ‘[None]’.


#Option 8

First we create the tickets_required() function that will return the least amount of tickets needed to so that the single act gig breaks even in the specific venue. Firstly this function calculates the average cost of all tickets sold, excluding the cancelled ones. Tickets that have price 0 may still be included as long as the related gig to that ticket was not cancelled. That’s why we first get the subset tickets that are not cancelled(i.e. their gigID does not exist in the the gigIDs of the subset of the gig table that contains entries with gigStatus=’Cancelled’). Right after we calculate the average we then proceeded with a mathematical formula consisting of the ceiling function and division to find how many average cost tickets we need to have at least the same as the hirecost and standardfee combined.  The function will return 0 in case the amount of tickets exceeds the capacity of the venue, otherwise it will return the least ticket number required that was just calculated.

##View option8: Regarding this view, table1 is a cross join of act and venue-since we want to try every combination- and we add as an extra column the result of the the tickets_required() function calculated for each row. From this table we select only the positive results of the function(for reasons specified above),  and we order by venueid ascending and ticket number descending as specified(while selecting to show only the rows venuename,actname,ticket_number).  
 

