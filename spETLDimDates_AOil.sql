USE TST_ApexOil;
Go
--********************************************************************--
-- This sp populates DimDates, automatically populating when the max sales date is past the max date in the table.
--********************************************************************--
IF OBJECT_ID ( 'spETLDimDates', 'P' ) IS NOT NULL 
    DROP PROCEDURE spETLDimDates
GO
Create Procedure spETLDimDates
/* Author: Jane Kuramoto


spETLDimDates

select max(Fulldate)
from dbo.DimDates

select max(Orderdate)
from dbo.SalesOrderHeader

select *
from dbo.DimDates



*/
AS
DECLARE @sdtMaxEndDatePlusTenYears SMALLDATETIME 
DECLARE @RepopulateDimDates BIT 



SELECT @sdtMaxEndDatePlusTenYears = DATEADD(YEAR,10,MAX(SOH.OrderDate))
FROM [TST_ApexOil].dbo.SalesOrderHeader SOH



Begin
Declare @RC int = 0;
Begin Try
-- ETL Processing Code --
--@sdtMaxEndDatePlusTenYears gets the max order date from dbo.SalesOrderHeader and adds ten years


/****** [dbo].[DimDates] ******/
-- Create  values for DimDates as needed.

-- Create variables to hold the start and end date
Declare @StartDate datetime = '06/01/2005'
Declare @EndDate datetime =  @sdtMaxEndDatePlusTenYears 

-- Use a while loop to add dates to the table
Declare @DateInProcess datetime
Set @DateInProcess = @StartDate

--SELECT MAX(FullDate)
--		  FROM dbo.DimDates
--		  HAVING MAX(FullDate) > @sdtMaxEndDatePlusTenYears


-- first check if the max sales date in DimDates + is greater than the max sales date + 10 years
IF EXISTS (SELECT MAX(FullDate)
		   FROM [TST_ApexOil].dbo.dimDates
		   HAVING MAX(FullDate) > @sdtMaxEndDatePlusTenYears) 
BEGIN
	ALTER TABLE [dbo].FactSalesOrders DROP CONSTRAINT [FK_FactSalesOrders_DimDates]
	TRUNCATE TABLE dbo.DimDates
END
IF ((SELECT COUNT(*)
	FROM [TST_ApexOil].dbo.dimDates) = 0)
BEGIN

WHILE @DateInProcess <= @EndDate
BEGIN
 -- Add a row into the date dimension table for this date
INSERT INTO dbo.DimDates	( [DateKey]
							, [FullDate] 
							, [FullDateName]
							, [MonthID]
							, [MonthName]
							, [YearID]
							, [YearName] )
 VALUES ( 
   CAST(CONVERT(VARCHAR(8),@DateInProcess,112) AS INT)
  , @DateInProcess -- [FullDate]
  , DateName( weekday, @DateInProcess )  -- [FullDateName]  
  , Month( @DateInProcess ) -- [MonthID]   
  , DateName( month, @DateInProcess ) -- [MonthName]
  , Year( @DateInProcess ) --YearID
  , Cast( Year(@DateInProcess ) as NVARCHAR(50) ) -- [YearName] 
  )  
 -- Add a day and loop again
 SET @DateInProcess = DateAdd(d, 1, @DateInProcess)
 END

-- 2e) Add additional lookup values to DimDates
--Set Identity_Insert [dbo].[DimDates] On
INSERT INTO [dbo].[DimDates]  ( [DateKey]
							  , [FullDate]
							  , [FullDateName]
							  , [MonthID]
							  , [MonthName]
							  , [YearID]
							  , [YearName] )
  SELECT 
    [DateKey] = -1
  , [FullDate] =  '01/01/1900'
  , [DateName] = Cast('Unknown Day' as NVARCHAR(50) )
  , [Month] = -1
  , [MonthName] = Cast('Unknown Month' as NVARCHAR(50) )
  , [Year] = -1
  , [YearName] = Cast('Unknown Year' as nVarchar(50) )
  UNION
  SELECT 
    [DateKey] = -2
  , [FullDate] = '01/01/1900' 
  , [DateName] = Cast('Corrupt Day' as NVARCHAR(50) )
  , [Month] = -2
  , [MonthName] = Cast('Corrupt Month' as NVARCHAR(50) )
  , [Year] = -2
  , [YearName] = Cast('Corrupt Year' as NVARCHAR(50) ) 

	

ALTER TABLE [dbo].[FactSalesOrders] ADD CONSTRAINT [FK_FactSalesOrders_DimDates]
	FOREIGN KEY ([OrderDateKey]) REFERENCES [dbo].[DimDates] ([DateKey])

--Delete From dbo.Customer Where  FirstName = 'Aaron' AND LastName = 'Adams'

--select max(orderdate), min(orderdate) from dbo.SalesOrderHeader

END

Set @RC = +1
End Try
Begin Catch


Print Error_Message()
Set @RC = -1
End Catch
Return @RC;
End
GO


