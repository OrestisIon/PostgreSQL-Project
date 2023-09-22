import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import java.io.IOException;
import java.util.Properties;

import java.time.LocalDateTime;
import java.sql.Timestamp;
import java.util.Vector;
import java.util.ArrayList;
import java.util.List;

public class GigSystem {

    public static void main(String[] args) {

        // You should only need to fetch the connection details once
        // You might need to change this to either getSocketConnection() or
        // getPortConnection() - see below
        Connection conn = getSocketConnection();

        boolean repeatMenu = true;

        while (repeatMenu) {
            System.out.println("_________________________");
            System.out.println("________GigSystem________");
            System.out.println("_________________________");

            System.out.println("1: Find the acts of a gig");
            System.out.println("2: ");
            System.out.println("3: ");
            System.out.println("4: ");
            System.out.println("5: ");
            System.out.println("q: ");

            String menuChoice = readEntry("Please choose an option: ");

            if (menuChoice.length() == 0) {
                // Nothing was typed (user just pressed enter) so start the loop again
                continue;
            }
            char option = menuChoice.charAt(0);

            /**
             * If you are going to implement a menu, you must read input before you call the
             * actual methods
             * Do not read input from any of the actual option methods
             */
            switch (option) {
                case '1':
                    int gigID = (int) Integer.parseInt(readEntry("gigID: "));
                    option1(conn, gigID);
                    break;

                case '2':
                    // String venue = readEntry("Venue: ");
                    // String gigTitle = readEntry("Gig Title: ");
                    // gigID = (int) Integer.parseInt(readEntry("gigID: "));
                    break;
                case '3':
                    break;
                case '4':
                    break;
                case '5':
                    break;
                case '6':
                    break;
                case '7':
                    break;
                case '8':
                    break;
                case 'q':
                    repeatMenu = false;
                    break;
                default:
                    System.out.println("Invalid option");
            }
        }
    }

    /*
     * You should not change the names, input parameters or return types of any of
     * the predefined methods in GigSystem.java
     * You may add extra methods if you wish (and you may overload the existing
     * methods - as long as the original version is implemented)
     */

    public static String[][] option1(Connection conn, int gigID) {
        String sql = "SELECT actname, ontime::TIME, getOffTime(ontime,duration)::TIME AS offtime FROM act_gig ag JOIN Act a USING (actID) WHERE ag.gigID = ? ORDER BY ontime asc; ";
        ResultSet r = null;
        PreparedStatement p;
        String[][] resultArray = null;
        try {
            p = conn.prepareStatement(sql);
            p.clearParameters();
            p.setInt(1, gigID);
            r = p.executeQuery();
            // Checking if query is null-- and avoids needing to backtrack
            if (r.isBeforeFirst())
                resultArray = convertResultToStrings(r);
            else
                return null;
        } catch (SQLException e) {
            e.printStackTrace();
        }
        printTable(resultArray);
        return resultArray;
    }

    public static void option2(Connection conn, String venue, String gigTitle, int[] actIDs, int[] fees,
            LocalDateTime[] onTimes, int[] durations, int adultTicketPrice) {
        // Turn transactions off.
        try {
            conn.setAutoCommit(false);
        } catch (SQLException e2) {
            e2.printStackTrace();
        }
        // First Find the Venue ID given the Venue name
        String sql = "SELECT venueid FROM venue v WHERE v.venuename=? ;";
        ResultSet rs = null;
        int venueid = 0;
        int gigID = 0;
        PreparedStatement p1;
        try {
            p1 = conn.prepareStatement(sql);
            p1.clearParameters();
            p1.setString(1, venue);
            rs = p1.executeQuery();
            // get the venueID of the venue with the same venuename as the parameter
            if (rs.next())
                venueid = rs.getInt(1);
            else
                return;
        } catch (SQLException e) {

            e.printStackTrace();
        }
        // statement us to insert the gig
        String sql1 = " INSERT INTO GIG (gigid, venueid, gigtitle, gigdate, gigstatus) VALUES (DEFAULT,?,?,?,DEFAULT); ";
        int r = 0;
        PreparedStatement stmt;
        PreparedStatement p;
        try {
            stmt = conn.prepareStatement(sql1, Statement.RETURN_GENERATED_KEYS);
            stmt.clearParameters();
            stmt.setInt(1, venueid);
            stmt.setString(2, gigTitle);
            stmt.setTimestamp(3, Timestamp.valueOf(onTimes[0]));
            r = stmt.executeUpdate();
            if (r <= 0)
                return;
            // Get the generated gigID of the new GIG row
            rs = stmt.getGeneratedKeys();
            if (rs.next())
                gigID = rs.getInt(1);
        } catch (SQLException e1) {

            e1.printStackTrace();
        }
        // statement us to insert the acts for each gig
        String sql3 = "INSERT INTO ACT_GIG (actid, gigid, actfee, ontime, duration) VALUES(?,?,?,?,?);";
        // iterating over an array
        // to insert every act_gig from the given array values
        for (int i = 0; i < actIDs.length; i++) {
            try {
                p = conn.prepareStatement(sql3);
                p.clearParameters();
                p.setInt(1, actIDs[i]);
                p.setInt(2, gigID);
                p.setInt(3, fees[i]);
                p.setTimestamp(4, Timestamp.valueOf(onTimes[i]));
                p.setInt(5, durations[i]);
                // If unsuccessful insert of an Act
                if ((r = p.executeUpdate()) <= 0) {
                    // Back to undo all new inserts
                    conn.rollback();
                    conn.setAutoCommit(true);
                    return;
                }
            } catch (SQLException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            }
            // Turn transactions off.

        }
        // Now insert the Gig_ticket
        sql1 = " INSERT INTO GIG_TICKET (gigid, pricetype, price) VALUES(?,'A',?); ";
        try {
            stmt = conn.prepareStatement(sql1);

            stmt.clearParameters();
            stmt.setInt(1, gigID);
            stmt.setInt(2, adultTicketPrice);
            r = stmt.executeUpdate();
            // if not successful then rollback all inserts
            if (r <= 0) {
                conn.rollback();
                conn.setAutoCommit(true);
                return;
            }
        } catch (SQLException e1) {

            e1.printStackTrace();
        }
        try {
            // Commit all the new inserts
            conn.commit();

            conn.setAutoCommit(true);
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public static void option3(Connection conn, int gigid, String name, String email, String ticketType) {
        // statement to gather the price of the ticket
        String sql1 = "SELECT price FROM gig_ticket g WHERE g.pricetype=? AND g.gigID=?";
        // statement to insert a new ticket with the parameter data
        String sql2 = "INSERT INTO TICKET (ticketid,gigid,CustomerName,CustomerEmail,pricetype,cost) VALUES (DEFAULT,?,?,?,?,?) ";
        ResultSet r = null;
        int r2 = 0;
        PreparedStatement p;
        PreparedStatement p2;
        int tempPrice = 0;
        try {
            p = conn.prepareStatement(sql1);
            p.clearParameters();
            p.setString(1, ticketType);
            p.setInt(2, gigid);
            r = p.executeQuery();
        } catch (SQLException e) {
            return;
        }
        try {
            // getting the price of the ticket
            if (r.next())
                tempPrice = r.getInt(1);
            else
                return;
        } catch (SQLException e) {
            return;
        } catch (NullPointerException l) {
            tempPrice = 0;
        }

        try {
            p2 = conn.prepareStatement(sql2);
            p2.clearParameters();
            p2.setInt(1, gigid);
            p2.setString(2, name);
            p2.setString(3, email);
            p2.setString(4, ticketType);
            p2.setInt(5, tempPrice);
            r2 = p2.executeUpdate();
            // If unsuccessful insert
            if (r2 <= 0)
                return;
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public static String[] option4(Connection conn, int gigID, String actName) {
        PreparedStatement p = null;
        CallableStatement p1;
        String sql;
        ResultSet rs = null;
        List<String> results = new ArrayList<String>();
        try {
            // calling procedure to delete the act from the gig
            sql = "CALL deleteAct_gig(?,?)";
            p1 = conn.prepareCall(sql);
            p1.clearParameters();
            // setting parameters to the procedure
            p1.setInt(1, gigID);
            p1.setString(2, actName);
            p1.execute();
            p1.close();
        } catch (SQLException e) {
            System.out.println(e);
        }
        // check if the gig got cancelled
        try {
            sql = "SELECT DISTINCT CustomerEmail FROM ticket t JOIN gig g USING(gigID) WHERE t.gigID=? AND g.gigstatus='Cancelled';";
            rs = null;
            p = conn.prepareStatement(sql);
            p.clearParameters();
            p.setInt(1, gigID);
            rs = p.executeQuery();
            int i = 0;
            // If it got cancelled the query will have the customeremails we need to return
            while (rs.next()) {
                results.add(rs.getString(1));
                System.out.println(results.get(i++));
            }
            if (results != null) {
                String[] resultsArray = new String[results.size()];
                resultsArray = results.toArray(resultsArray);
                return resultsArray;
            }
        } catch (SQLException e) {
            System.out.println(e);
        }
        return null;

    }

    public static String[][] option5(Connection conn) throws SQLException {

        // String sql = "SELECT *, COALESCE(Expenditures,0) - COALESCE(Profits,0) as
        // balance FROM expenses e FULL OUTER JOIN sales s ON e.gigID=s.gigID ORDER BY
        // e.gigID asc; ";
        // String sql2="SELECT DISTINCT gigID, price FROM gig_ticket WHERE pricetype='A'
        // ORDER BY gigID asc;";
        // SELECT CEIL(balance::double precision/price::double precision) FROM (SELECT
        // *, COALESCE(Expenditures,0) - COALESCE(Profits,0) as balance FROM expenses e
        // FULL OUTER JOIN sales s ON e.gigID=s.gigID) a JOIN gig_ticket b WHERE
        // b.pricetype='A' ORDER BY gigID asc;
        // View readme for further detail on query
        String sql = "SELECT gigID,CEIL(balance::double precision/price::double precision)::INT as amount FROM (SELECT e.gigID, COALESCE(Expenditures,0) - COALESCE(Profits,0) as balance  FROM expenses e FULL OUTER JOIN sales s ON e.gigID=s.gigID) a JOIN gig_ticket b USING(gigID) WHERE b.pricetype='A' AND b.price<>0 ORDER BY gigID asc";
        ResultSet r1 = null;
        int amount;
        String[][] result;
        PreparedStatement p1 = conn.prepareStatement(sql);
        p1.clearParameters();
        r1 = p1.executeQuery();
        if (r1.isBeforeFirst()) {
            result = convertResultToStrings(r1);
        } else
            return null;
        // printTable(result);
        return result;
    }

    public static String[][] option6(Connection conn) {
        // prepare statement to get immediatly query results that we want
        String sql = "SELECT actname,year,count FROM option6;";
        PreparedStatement p1;
        ResultSet r1 = null;
        String[][] solution = null;
        try {
            p1 = conn.prepareStatement(sql);
            r1 = p1.executeQuery();
            if (r1.isBeforeFirst())
                solution = convertResultToStrings(r1);
        } catch (SQLException e) {
            e.printStackTrace();
        }
        // if (solution != null)
        // printTable(solution);
        return solution;
    }

    public static String[][] option7(Connection conn) {
        // prepare statement to get immediatly query results that we want
        String sql = "SELECT * FROM option7;";
        PreparedStatement p1;
        ResultSet r1 = null;
        String[][] solution = null;
        try {
            p1 = conn.prepareStatement(sql);
            r1 = p1.executeQuery();
            // if there are results
            if (r1.isBeforeFirst())
                // add them to a string array
                solution = convertResultToStrings(r1);
        } catch (SQLException e) {
            e.printStackTrace();
        }
        // if (solution != null)
        // printTable(solution);
        return solution;
    }

    public static String[][] option8(Connection conn) {
        // Query to get wanted results
        String sql = "SELECT * FROM option8;";
        PreparedStatement p1;
        ResultSet r1 = null;
        String[][] solution = null;
        try {
            p1 = conn.prepareStatement(sql);
            r1 = p1.executeQuery();
            // if there are results
            if (r1.isBeforeFirst())
                // add them to a string array
                solution = convertResultToStrings(r1);
        } catch (SQLException e) {
            e.printStackTrace();
        }
        // if(solution!=null)
        // printTable(solution);
        return solution;
    }

    /**
     * Prompts the user for input
     * 
     * @param prompt Prompt for user input
     * @return the text the user typed
     */

    private static String readEntry(String prompt) {

        try {
            StringBuffer buffer = new StringBuffer();
            System.out.print(prompt);
            System.out.flush();
            int c = System.in.read();
            while (c != '\n' && c != -1) {
                buffer.append((char) c);
                c = System.in.read();
            }
            return buffer.toString().trim();
        } catch (IOException e) {
            return "";
        }

    }

    /**
     * Gets the connection to the database using the Postgres driver, connecting via
     * unix sockets
     * 
     * @return A JDBC Connection object
     */
    public static Connection getSocketConnection() {
        Properties props = new Properties();
        props.setProperty("socketFactory", "org.newsclub.net.unix.AFUNIXSocketFactory$FactoryArg");
        props.setProperty("socketFactoryArg", System.getenv("HOME") + "/cs258-postgres/postgres/tmp/.s.PGSQL.5432");
        Connection conn;
        try {
            conn = DriverManager.getConnection("jdbc:postgresql://localhost/cwk", props);
            return conn;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    /**
     * Gets the connection to the database using the Postgres driver, connecting via
     * TCP/IP port
     * 
     * @return A JDBC Connection object
     */
    public static Connection getPortConnection() {

        String user = "postgres";
        String passwrd = "password";
        Connection conn;

        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException x) {
            System.out.println("Driver could not be loaded");
        }

        try {
            conn = DriverManager
                    .getConnection("jdbc:postgresql://127.0.0.1:5432/cwk?user=" + user + "&password=" + passwrd);
            return conn;
        } catch (SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
            System.out.println("Error retrieving connection");
            return null;
        }
    }

    public static String[][] convertResultToStrings(ResultSet rs) {
        Vector<String[]> output = null;
        String[][] out = null;
        try {
            int columns = rs.getMetaData().getColumnCount();
            output = new Vector<String[]>();
            int rows = 0;
            while (rs.next()) {
                String[] thisRow = new String[columns];
                for (int i = 0; i < columns; i++) {
                    thisRow[i] = rs.getString(i + 1);
                }
                output.add(thisRow);
                rows++;
            }
            // System.out.println(rows + " rows and " + columns + " columns");
            out = new String[rows][columns];
            for (int i = 0; i < rows; i++) {
                out[i] = output.get(i);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return out;
    }

    public static void printTable(String[][] out) {
        int numCols = out[0].length;
        int w = 20;
        int widths[] = new int[numCols];
        for (int i = 0; i < numCols; i++) {
            widths[i] = w;
        }
        printTable(out, widths);
    }

    public static void printTable(String[][] out, int[] widths) {
        for (int i = 0; i < out.length; i++) {
            for (int j = 0; j < out[i].length; j++) {
                System.out.format("%" + widths[j] + "s", out[i][j]);
                if (j < out[i].length - 1) {
                    System.out.print(",");
                }
            }
            System.out.println();
        }
    }

}
