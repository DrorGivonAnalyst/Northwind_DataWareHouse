
--CREATE TABLE Dim_Date
USE Northwind_DW
GO
	CREATE TABLE [Northwind_DW].[dbo].[Dim_Date]
	(
		[DateKey] [int] identity(1,1) PRIMARY KEY NOT NULL,
		[Date] Date NOT NULL,
		[Year] int NOT NULL,
		[Quarter] int NOT NULL,
		[Month] int NOT NULL,
		[MonthName] nvarchar(20) NOT NULL
	)
--DATE RANGE FUNCTION FOR PROCEDURE
CREATE FUNCTION [dbo].[FUN_DateRange]
(     
      @StartDate DATE,
      @EndDate DATE
)
RETURNS TABLE 
RETURN
	WITH seq(DateKey) AS 
	(SELECT 0 AS DateKey UNION ALL SELECT DateKey + 1 FROM seq WHERE DateKey < DATEDIFF(day, @StartDate, @EndDate)),
	d(DateKey,d) AS 
	(SELECT DateKey+1, DATEADD(DAY, DateKey, @StartDate) FROM seq),
	src AS
	(SELECT
		DateKey,
		[Date] = CONVERT(date, d),
		[Month] = CONVERT(int, DATEPART(MONTH, d)),
		[MonthName] = CONVERT(NVARCHAR(20), DATENAME(MONTH, d)),
		[Quarter] = DATEPART(Quarter, d),
		[Year] = DATEPART(YEAR, d)
	FROM d),
	dim AS
	(SELECT
		[Date], 
		[Month],
		[MonthName],
		[Quarter],
		[Year]
	FROM src)
SELECT * FROM dim 

--PROCEDURE DATE RANGE WITH StartDate $ EndDate
alter PROCEDURE UpDate_DateRnge 
AS
--First Delete all Data from Dim's Tables 
	TRUNCATE TABLE [Northwind_DW].[dbo].[Dim_Customers];
	TRUNCATE TABLE [Northwind_DW].[dbo].[Dim_Date];
	TRUNCATE TABLE [Northwind_DW].[dbo].[Dim_Employees];
	TRUNCATE TABLE [Northwind_DW].[dbo].[Dim_Orders];
	TRUNCATE TABLE [Northwind_DW].[dbo].[Dim_Products];
	TRUNCATE TABLE [Northwind_DW].[dbo].[Fact_Sales];

--Import Customers Table	
	INSERT INTO [Northwind_DW].[dbo].[Dim_Customers]
	SELECT CustomerID, CompanyName, City, Region, Country
	FROM [northwnd].[dbo].[Customers];
--Import Date Table	
	INSERT INTO [Northwind_DW].[dbo].[Dim_Date] ([DateKey], [date], [Month], [MonthName], [Quarter], [Year])
	SELECT * FROM [Northwind_DW].[dbo].[FUN_DAteRange]('19960101','19991231') OPTION (maxrecursion 0);
--Import Employees Table
	INSERT INTO [Northwind_DW].[dbo].[Dim_Employees]
	SELECT EmployeeID, LastName, FirstName, LastName + ' ' + FirstName, Title, BirthDate,(CAST(GETDATE() as int) - CAST(birthdate as int))/365, HireDate, (CAST(GETDATE() as int) - CAST(HireDate as int))/365, City, Country, Photo,ReportsTo
	FROM [northwnd].[dbo].[Employees];
--Import Orders Table
	INSERT INTO [Northwind_DW].[dbo].[Dim_Orders]
	SELECT OrderID, ShipCity, ShipRegion,ShipCountry
	FROM [northwnd].[dbo].[Orders];
--Import Products Table
	DECLARE 
		@PriceAVG MONEY
	SET @PriceAVG = (SELECT AVG(UnitPrice) FROM [northwnd].[dbo].[Products])
	INSERT INTO [Northwind_DW].[dbo].[Dim_Products]
	SELECT P.ProductID, P.ProductName, P.UnitPrice, 
		CASE
			WHEN P.UnitPrice > @PriceAVG THEN 'Expensive'
			ELSE 'Cheap'
			END AS [Price_Category],
		C.CategoryName, S.CompanyName, P.Discontinued
	FROM  [northwnd].[dbo].[Products] P 
		JOIN  [northwnd].[dbo].[Categories] C
		ON C.CategoryID = P.CategoryID
		JOIN  [northwnd].[dbo].[Suppliers] S 
		ON P.SupplierID = S.SupplierID;
--Import Fact_Sales Table
	INSERT INTO [Northwind_DW].[dbo].[Fact_Sales](OrderSK, ProductSK, DateKey, CustomerSK, EmployeeSK, UnitPrice,Quantity,Discount)
	SELECT DimO.OrderSK , DimP.ProductSK, DimD.DateKey, DimC.CustomerSK, DimE.EmployeeSK, OD.UnitPrice, OD.Quantity, OD.Discount
	FROM [NORTHWND].[dbo].[Orders] O
		JOIN [NORTHWND].[dbo].[Order Details] OD
		ON OD.OrderID = O.OrderID
		JOIN [Northwind_DW].[dbo].[Dim_Orders] DimO
		ON O.OrderID = DimO.OrderBK
		JOIN [Northwind_DW].[dbo].[Dim_Products] DimP
		ON DImP.ProductBK = OD.ProductID
		JOIN [Northwind_DW].[dbo].[Dim_Date] DimD
		ON DimD.Date = O.OrderDate
		JOIN [Northwind_DW].[dbo].[Dim_Employees] DimE
		ON DimE.EmployeeBK = O.EmployeeID
		JOIN [Northwind_DW].[dbo].[Dim_Customers] DimC
		ON DimC.CustomerBK = O.CustomerID
COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

--Test 1
EXEC UpDate_DateRnge

SELECT * FROM [Northwind_DW].[dbo].[Dim_Customers] --91
SELECT * FROM [Northwind_DW].[dbo].[Dim_Date] --1461
SELECT * FROM [Northwind_DW].[dbo].[Dim_Employees] --9
SELECT * FROM [Northwind_DW].[dbo].[Dim_Orders] --830
SELECT * FROM [Northwind_DW].[dbo].[Dim_Products] --77
SELECT * FROM [Northwind_DW].[dbo].[Fact_Sales] --2155

