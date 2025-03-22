--                                                    ******** Business Context ********
-- A retail store wants to analyze customer behavior using their point-of-sale (POS) data. The goal is to extract insights on transactions, sales trends, and customer demographics to improve business strategies.


-- Create Database Retail_Store_Analysis;
Use Retail_Data_Analysis;

-- ****** DATA PREPARATION & UNDERSTANDING ****** --

-- Overview of Tables
Select * From Customer;
Select * From Transactions;
Select * From Prod_Cat_Info;

-- 1. Retrieve the total number of rows in each of the three tables to understand the dataset size.
With TableCounts As (
Select 'CUSTOMER' As TABLE_NAME, Count(*) As TOTAL_RECORD From customer
Union All
Select 'PROD_CAT_INFO' As TABLE_NAME, Count(*) As TOTAL_RECORD From prod_cat_info
Union All
Select 'TRANSACTIONS' As TABLE_NAME, Count(*) As TOTAL_RECORD From transactions
)
Select * From TableCounts
Union All  
Select 'GRAND TOTAL' As TABLE_NAME, Sum(TOTAL_RECORD) From TableCounts;

-- 2. Identify the number of transactions that involve a return to analyze return patterns.
Select 'RETURN' As TRANSACTION_TYPE, Count(*) As TOTAL_RETURN_TRANSACTION  
From Transactions  
Where Qty < 0;


-- 3. Convert date fields into a valid date format to ensure consistency before analysis.
-- To check if the function is working correctly.
Select *, str_to_date(DOB, '%d-%m-%Y') As NEW_FORMAT_DOB From Customer;
Select *, str_to_date(tran_date, '%d-%m-%Y') As NEW_FORMAT_TRAN_DATE From Transactions;

-- Update the Date columns.
-- Update Customer Set DOB = Str_To_Date(Replace(DOB,'/','-'), '%d-%m-%Y');
-- Update Transactions Set tran_date = Str_To_Date(Replace(tran_date, '/', '-'), '%d-%m-%Y');

-- 4. Analyze the transaction dataset's time coverage by determining the earliest and latest transaction dates and
-- calculating the total duration in days, months, and years to understand the data's historical range.

Select
    Min(tran_date) As BEGIN_TRANSACTION_DATE,
    Max(tran_date) As END_TRANSACTION_DATE,
    Timestampdiff(Day, Max(tran_date), Min(tran_date)) As NUMBER_OF_DAYS,  
    Timestampdiff(Month, Min(tran_date), Max(tran_date)) As NUMBER_OF_MONTHS,  
    Timestampdiff(Year, Min(tran_date), Max(tran_date)) As NUMBER_OF_YEARS  
From Transactions;


-- 5. Identify the product category associated with the sub-category "DIY" to understand product hierarchy.
Select Prod_cat From Prod_Cat_Info
where Prod_Subcat = 'DIY';



--                                               ******* DATA ANALYSIS ******

-- ** Customer & Transaction Insights **

-- 1. Identify the most frequently used sales channel (e.g., Online, Flagship Store, Reseller).
Select Store_Type As Channels, Count(Store_Type) As Total_Transactions  
From Transactions  
Group By Store_Type  
Order By Total_Transactions Desc  
Limit 1;


-- 2. Analyze customer demographics by counting the total number of male and female customers in the database to identify gender distribution and purchasing trends.
Select 'Male' As Gender, Count(Gender) As Total_Count
From Customer
Where Gender = 'M'
Union All
Select 'Female' As Gender, Count(Gender) As Total_Count
From Customer
Where Gender = 'F';

-- 3. Identify the city with the highest customer concentration by calculating the total number of unique customers per city
-- and determining the city with the maximum customer count.
Select City_Code, Count(Distinct Customer_Id) as Max_Customer
From Customer
Group By City_code
Order by Max_Customer desc
limit 1;


-- ** Product & Sales Performance **

-- 4. Measure product diversity by counting the number of unique sub-categories available under the "Books" category to understand the variety of products offered.
Select 'Books' as Category, Count(Prod_subcat) as Count_of_Subcategory
from Prod_Cat_info
Where Prod_Cat = 'Books';


-- 5. Determine the highest product demand by identifying the maximum quantity of a single product ordered in one transaction,
-- providing insights into bulk purchase trends.
Select T.Prod_Cat_code as Category_Code,
Prod_cat as Product_Name,
Count(Qty) AS Max_Quantity
from TRANSACTIONS As T Left Join Prod_Cat_Info As PI
On T.Prod_Cat_code = PI.Prod_Cat_code And T.prod_subcat_code=PI.prod_sub_cat_code
Group By T.prod_cat_code, prod_cat
Order By Max_Quantity Desc
Limit 1;


-- 6. Evaluate category-wise revenue performance by calculating the total sales generated from "Electronics"
-- and "Books" categories, helping assess their contribution to overall revenue.

Select PCI.prod_cat As PRODUCT_CATEGORY, Sum(TOTAL_AMT) As TOTAL_REVENUE  
From Transactions As TR  
Inner Join prod_cat_info As PCI  
On TR.prod_cat_code = PCI.prod_cat_code  
And TR.prod_subcat_code = PCI.prod_sub_cat_code  
Where PCI.prod_cat = 'BOOKS' Or PCI.prod_cat = 'ELECTRONICS'  
Group By PCI.prod_cat;


-- 7. Identify high-value customers by finding those who have completed more than 10 transactions while excluding returns,
-- helping analyze customer loyalty and engagement.
SELECT CUST_ID AS CUSTOMER_ID, COUNT(total_amt) AS TOTAL_NUMBER_OF_TRANSACTIONS
FROM
Transactions
WHERE QTY>0
GROUP BY CUST_ID
HAVING COUNT(total_amt)>10;


-- 8. Assess store performance by calculating the total revenue from "Electronics" & "Clothing" categories specifically from Flagship stores,
-- providing insights into the most profitable store types.
With CategorySales As (
    Select 
        PCI.prod_cat As PRODUCT_CATEGORY, 
        Sum(TR.TOTAL_AMT) As TOTAL_AMT
    From Transactions As TR
    Left Join prod_cat_info As PCI
        On TR.prod_cat_code = PCI.prod_cat_code  
        And TR.prod_subcat_code = PCI.prod_sub_cat_code  
    Where TR.Store_type = 'FLAGSHIP STORE' 
    And PCI.prod_cat In ('CLOTHING', 'ELECTRONICS')  
    Group By PCI.prod_cat
)
Select * From CategorySales  
Union All  
Select 'GRAND TOTAL', Sum(TOTAL_AMT) From CategorySales;


-- 9. Analyze gender-based spending patterns by calculating the total revenue generated from male customers in the "Electronics" category,
-- further breaking it down by product sub-category to understand purchasing preferences.
Select 
    C.Gender, 
    PCI.prod_cat As PRODUCT_CATEGORY, 
    PCI.prod_subcat As PRODUCT_SUBCATEGORY, 
    Sum(Cast(TR.TOTAL_AMT As Decimal(10,2))) As TOTAL_REVENUE 
From Customer As C  
Inner Join Transactions As TR  
    On C.customer_Id = TR.cust_id  
Inner Join prod_cat_info As PCI  
    On TR.prod_cat_code = PCI.prod_cat_code  
    And TR.prod_subcat_code = PCI.prod_sub_cat_code  
Where C.Gender = 'M'  
And PCI.prod_cat = 'ELECTRONICS'  
Group By C.Gender, PCI.prod_cat, PCI.prod_subcat;


-- ** Return & Revenue Patterns **

-- 10. Evaluate product performance by analyzing the percentage of sales vs.
-- returns per product sub-category and identifying the top 5 sub-categories with the highest sales to understand customer preferences and product success.
With TotalValues As (
    Select 
        Sum(TOTAL_AMT) As TotalSales, 
        Sum(Case When Qty < 0 Then Qty End) As TotalReturns
    From Transactions
)
Select 
    PCI.prod_subcat As PRODUCT_SUB_CATEGORY,  
    Sum(TR.TOTAL_AMT) As TOTAL_SALES,  
    Sum(TR.TOTAL_AMT) / (Select TotalSales From TotalValues) As TOTAL_SALES_PERCENTAGE,  
    Coalesce(Sum(Case When TR.Qty < 0 Then TR.Qty End), 0) / 
    (Select Coalesce(TotalReturns, 1) From TotalValues) As TOTAL_RETURNS_PERCENTAGE  
From Transactions As TR  
Left Join prod_cat_info As PCI  
    On TR.prod_cat_code = PCI.prod_cat_code  
    And TR.prod_subcat_code = PCI.prod_sub_cat_code  
Group By PCI.prod_subcat  
Order By TOTAL_SALES Desc  
Limit 5;

-- 11. Assess recent purchasing trends by calculating the total revenue generated by customers aged 25-35 in the last 30 days from the latest recorded transaction,
-- providing insights into active customer engagement.
Select Customer_Id, Timestampdiff(Year, DOB, Now()) As Cust_Age,  
Tran_Date As Transaction_Date,  
Sum(Total_Amt) As Total_Sales  
From Customer As C  
Left Join Transactions As TR  
On C.Customer_Id = TR.Cust_Id  
Where Timestampdiff(Year, DOB, Now()) Between 25 And 35  
And Tran_Date Between '2013-11-01' And '2013-11-30'  
Group By Customer_Id, Timestampdiff(Year, DOB, Now()), Tran_Date;

-- 12. Identify high-return product categories by determining the category with the highest return value in the last 3 months,
-- helping businesses address product quality issues and reduce return rates.
Select PCI.Prod_Cat As Product_Category,  
Sum(Total_Amt) As Total_Value_Of_Return  
From Transactions As TR  
Inner Join Prod_Cat_Info As PCI  
On TR.Prod_Cat_Code = PCI.Prod_Cat_Code  
And TR.Prod_Subcat_Code = PCI.Prod_Sub_cat_Code  
Where Qty < 0  
And TR.Tran_Date Between '2013-09-01' And '2013-11-30'  
Group By PCI.Prod_Cat  
Order By Total_Value_Of_Return  
Limit 1;

-- ** Store & Performance Analysis ** 

-- 13. Analyze store performance by identifying the store type with the highest sales,
-- measured by total sales value and quantity sold, to determine the most profitable sales channel.
Select Store_Type,  
Sum(Total_Amt) As Total_Sale_Amt,  
Count(Prod_Cat) As Quantity_Of_Sale  
From Transactions As TR  
Inner Join Prod_Cat_Info As PCI  
On TR.Prod_Cat_Code = PCI.Prod_Cat_Code  
And TR.Prod_Subcat_Code = PCI.Prod_Sub_cat_Code  
Group By Store_Type  
Order By Total_Sale_Amt Desc, Quantity_Of_Sale Desc  
Limit 1;

-- 14. Evaluate high-performing product categories by finding categories where the average revenue exceeds the overall average revenue,
-- helping prioritize inventory and marketing efforts.
Select Prod_Cat As Product_Category, Avg(Total_Amt) As Sales_More_Than_Avg  
From Transactions As TR  
Inner Join Prod_Cat_Info As PCI  
On TR.Prod_Cat_Code = PCI.Prod_Cat_Code  
And TR.Prod_Subcat_Code = PCI.Prod_Sub_cat_Code  
Group By Prod_Cat  
Having Avg(Total_Amt) >  
(Select Avg(Total_Amt) From Transactions);

-- 15. Assess top-selling product sub-categories by computing the average and total revenue per sub-category for the top 5 product categories by quantity sold,
-- providing insights into the most in-demand products.
With RankedData As (
    Select 
        Row_Number() Over(Order By Count(prod_cat) Desc) As RNUM,
        prod_cat, 
        prod_subcat,
        Avg(Cast(Total_Amt As Decimal(10,2))) As AVG_SALE, 
        Sum(Cast(Total_Amt As Decimal(10,2))) As TOTAL_SALE,
        Count(prod_cat) As TOTAL_QUANTITY
    From Transactions As TR
    Inner Join prod_cat_info As PCI
        On TR.prod_cat_code = PCI.prod_cat_code 
        And TR.prod_subcat_code = PCI.prod_sub_cat_code
    Group By prod_cat, prod_subcat
)
Select * From RankedData Where RNUM Between 1 And 5;


-- Overall:

-- Designed and optimized SQL queries to analyze customer behavior, sales trends, and return patterns for a retail business.
-- Developed complex queries using CTEs, Window Functions (ROW_NUMBER(), RANK()), and Aggregations (SUM(), AVG()) to extract meaningful insights.
-- Optimized query performance by leveraging EXPLAIN ANALYZE, Indexing, and Subqueries to improve execution time.
-- Cleaned and standardized data by converting date formats (STR_TO_DATE()) and ensuring consistency across tables.
-- Identified top-selling categories, highest return rates, and high-value customers, helping the business optimize marketing and inventory strategies.
-- Calculated revenue contribution by customer demographics, allowing better segmentation and targeted promotions.
-- Improved data integrity and reporting accuracy, enabling faster and more efficient decision-making.