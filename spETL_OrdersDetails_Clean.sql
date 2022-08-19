USE TST


/* =============================================  
 Author:  J Kuramoto
 Create date: Feb 16, 2022
 Description: Remove records with NULL Price, Units from tblOrderDetails. Convert numeric nvarchar columns to numeric to
	allow calculations and reconciliation. 

2/23/2022		J Kuramoto		

--example of cleanup items
SELECT  o.Retailer, o.OrderDate, od.InvoiceID, od.ItemNo, REPLACE(REPLACE(od.Linetotal,'$',''), ',','') AS LineTotal, od.Linetotal, od.Total
from dbo.tblOrderDetails od
inner join dbo.tblOrders o on o.InvoiceID = od.InvoiceID
WHERE od.InvoiceID IN (2201374, 2214725, 2226020)


select * from dbo.tblOrderDetails where brand = 'test' and InvoiceID = 2226026

exec spETL_OrderDetails_Clean
 =============================================  */

 
If (object_id('[spETL_OrderDetails_Clean]') is not null) Drop Procedure [spETL_OrderDetails_Clean];
Go
CREATE OR ALTER PROCEDURE [spETL_OrderDetails_Clean] 
 

AS
BEGIN
SET ANSI_WARNINGS OFF;
 
 
BEGIN TRY
BEGIN TRANSACTION;   

WITH OrderDetails  (InvoiceID, OrderAddOn, Units, SampleType, Price, Linetotal, CreatedOn, CreatedBy, ItemNo, Brand, WeekLastDate)
AS 
(SELECT CONVERT(INT, p.InvoiceID) AS InvoiceID
				, CONVERT(NVARCHAR(255),p.OrderAddOn) AS OrderAddOn
				, CONVERT(NUMERIC(8,2), TRIM(p.Units)) AS Units 
				, NULL AS SampleType
				, CONVERT(NUMERIC(8,2),TRIM(p.Price)) AS Price 
				, CONVERT(NUMERIC(8,2), TRIM(p.Linetotal)) AS Linetotal     
				, CONVERT(smalldatetime, p.CreatedOn)  as CreatedOn
				, p.CreatedBy  
				, CONVERT(INT, TRIM(p.ItemNo)) AS ItemNo
				, p.Brand  
				, CONVERT(smalldatetime,p.WeekLastDate) AS WeekLastDate
			--	, GetDate() AS UploadDate
 FROM ( SELECT CONVERT(INT,InvoiceID) AS InvoiceID
				 , OrderAddOn 
				 , rtrim(Units) AS Units
				 , REPLACE(Price,'$','') AS Price
				 , REPLACE(REPLACE(Linetotal,'$',''), ',','') AS LineTotal
				 , CreatedOn  
				 , CreatedBy  
				 , rtrim(ItemNo) AS ItemNo
				 , rtrim(ISNULL(Brand,'NA')) AS Brand
				 , WeekLastDate 
	 FROM dbo.tblOrderDetails
	 WHERE Units IS NOT NULL AND ISNUMERIC(Units) = 1) p

	 -- load records containing non numeric Units 
	 UNION
	 SELECT CONVERT(INT,p2.InvoiceID) AS InvoiceID
				, CONVERT(NVARCHAR(255),p2.OrderAddOn) AS OrderAddOn
				, CONVERT(NUMERIC(8,2), p2.Units) AS Units 
				, p.SampleType
				, CONVERT(NUMERIC(8,2),TRIM(p2.Price)) AS Price 
				, CONVERT(NUMERIC(8,2), TRIM(p2.Linetotal)) AS Linetotal     
				, CONVERT(smalldatetime, p2.CraetedOn) AS CreatedOn
				, p2.CreatedBy  
				, CONVERT(INT, TRIM(p2.ItemNo)) AS ItemNo
				, p2.Brand  
				, CONVERT(smalldatetime,p2.WeekLastDate) AS WeekLastDate
			--	, GetDate() AS UploadDate
	  FROM ( SELECT CONVERT(INT,InvoiceID) AS InvoiceID
				 , OrderAddOn 
				 , rtrim(0) AS Units 
				 , rtrim([Type]) AS SampleType
				 , REPLACE(Price,'$','') AS Price
				 , REPLACE(REPLACE(Linetotal,'$',''), ',','') AS LineTotal
				 , CreatedOn 
				 , CreatedBy  
				 , rtrim(ItemNo) AS ItemNo
				 , rtrim(ISNULL(Brand,'NA')) AS Brand
				 , WeekLastDate 
	 FROM dbo.tblOrderDetails
	 WHERE  Units IN ('edu', 'ns')  )  p2)


	--	AND  CreatedOn > (SELECT TOP 1 MAX(CreatedOn) FROM dbo.OrderDetails_Clean)) pp


--SET @intRecordCountBeforeLoad = (select count(*) as CountBeforeLoad from dbo.OrderDetails_Clean)
--select count(*) from dbo.OrderDetails
	

	---- Isolate the differences.
	INSERT INTO dbo.tblOrderDetail_Clean
		(			 InvoiceID  
					, OrderAddOn   
					, Units 
					, SampleType
					, Price 
					, Linetotal 
					, CreatedOn
					, CreatedBy
					, ItemNo
					, Brand
					, WeekLastDate)   
	SELECT			InvoiceID  
					 , OrderAddOn   
					 , Units 
					 , SampleType
					 , Price 
					 , Linetotal 
					 , CreatedOn
					 , CreatedBy
					 , ItemNo
					 , Brand
					 , WeekLastDate
	FROM dbo.tblOrderDetails  
	EXCEPT
	SELECT			 InvoiceID  
					 , OrderAddOn  
					 , Units 
					 , SampleType
					 , Price 
					 , Linetotal 
					 , CreatedOn
					 , CreatedBy
					 , ItemNo
					 , Brand
					 , WeekLastDate 
	FROM dbo.tblOrderDetails_Clean;

							 

COMMIT TRANSACTION

END TRY

BEGIN CATCH
  
  IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
-- Error Message

  
    DECLARE @ErrorMessage NVARCHAR(4000);    
    DECLARE @ErrorSeverity INT;    
    DECLARE @ErrorState INT; 
    DECLARE @ErrorProcedure NVARCHAR(100);
    DECLARE @ErrorNumber    INT;
    DECLARE @ErrorLine INT;

  
    SELECT     
       @ErrorMessage = ERROR_MESSAGE(),    
       @ErrorSeverity = ERROR_SEVERITY(),    
       @ErrorState = ERROR_STATE(),
       @ErrorProcedure = ERROR_PROCEDURE(),
       @ErrorNumber = ERROR_NUMBER(),
       @ErrorLine = ERROR_LINE()
  
    RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorNumber, @ErrorLine);
END CATCH
END 
GO
   