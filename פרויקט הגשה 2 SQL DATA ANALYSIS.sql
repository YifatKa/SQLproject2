--פרוייקט הגשה שני SQL - קורס דאטה אנליסט ג'ון ברייס 
-- מרצה אלעד שליו
-- מגישה : יפעת קדמון 

--1. מידע על מוצרים שלא נרכשו בטבלת ההזמנות
--use subQ where the product not exists / not in. all prodect is p.productid = s.productid. 
--need  just p.productid that not in s.productid  

select  distinct p.ProductID, p.Name as 'productname', p.Color, p.ListPrice, p.Size
from Production.Product p 
where p.ProductID not in ( select  s.ProductID 
from sales.SalesOrderDetail s)


-----
update sales.Customer set PersonID = CustomerID 
where CustomerID<=290 

update sales.Customer set PersonID = CustomerID+1700
where CustomerID >= 300 and CustomerID <=350

update sales.Customer set PersonID = CustomerID+1700
where CustomerID>= 352 and CustomerID <= 701

-----
 -- 2. information on customer without orders
 -- 2 options to answer. with join in subQ or without. 
 

select  c.CustomerID, 
		isnull (p.FirstName,'unknown') as 'FirstName' ,
		isnull (p.LastName,'unknown') as 'LastName'
 from sales.Customer c left join Person.Person p
 on c.CustomerID = p.BusinessEntityID
 where c.CustomerID not in ( select CustomerID from sales.SalesOrderHeader )
 order by c.CustomerID


--3. top 10 Peak orders custumers 
-- count not in group by

select top 10 soh.CustomerID, p.FirstName, p.LastName, count(soh.SalesOrderID) as 'countoforders'
 from  sales.salesorderheader soh left join Person.Person p
 on soh.CustomerID = p.BusinessEntityID 
 group by soh.customerid,p.firstname, p.LastName
 order by count(soh.SalesOrderID) desc

--4. employee & title. how neny employees whith the same title
-- we can use over and partition by instead of group by .

select pp.FirstName, pp.LastName, hre.JobTitle, hre.HireDate, 
count (*) over (partition by hre.JobTitle) as 'countoftitle'
from HumanResources.Employee hre left join Person.Person pp
on hre.BusinessEntityID = pp.BusinessEntityID

--5. the  last 2 orders date for each customer
-- להשתמש בlag ולצרף גם את טבלת customer 
--לשים לב שSalesOrderID  לא בgroup by. 
--2 שלבים . 1. להביא את כל המידע הרלוונטי לטבלה. 2. לסדר אותם לפי max 

GO
with CTE_orderdate_customer 
as
(select soh.SalesOrderID,
		c.CustomerID,
		p.LastName,
		p.FirstName, 
		soh.OrderDate as 'LastOrder', 
		lag(soh.OrderDate) over (partition by soh.CustomerID order by soh.OrderDate)  as 'PreviousOrder'
 from  Person.Person p
 join sales.Customer c on p.BusinessEntityID = c.PersonID
 join sales.SalesOrderHeader soh on soh.CustomerID= c.CustomerID)
 select max(coc.SalesOrderID) as salesorderid,
		coc.CustomerID,
		coc.LastName,
		coc.FirstName,
		max(coc.[LastOrder]) as 'LastOrder',
		max(coc.[PreviousOrder])  as 'PreviousOrder'
 from CTE_orderdate_customer coc
 GROUP BY coc.CustomerID, coc.FirstName, coc.LastName
 ORDER BY coc.CustomerID DESC
 
  
 --6. max linetotal for orderid in 1  year and who is the customer of this order
 -- 3 שלבים: 
 --1. לסכום לכל לקוח את סך ההזמנות לפי שנה. 
 --2. להוציא את ההזמנה הגבוהה ביותר לכל שנה. 
 --3. לשלוף את הנתונים יחד בהצלבה 

GO
with CTE_sumorder_for_year 
AS 
(select YEAR(soh.OrderDate) as [year],
		soh.SalesOrderID,
		p.LastName as [LastName]  ,
		p.FirstName as [FirstName] ,
		sum((sod.UnitPrice)*(1-sod.UnitPriceDiscount)*sod.OrderQty) as [sumorder] 
 from  sales.SalesOrderDetail sod join sales.salesorderheader soh
 on sod.SalesOrderID = soh.SalesOrderID 
 join sales.Customer c
 on soh.CustomerID = c.CustomerID
 join person.Person p  on c.personid = p.BusinessEntityID
 group by YEAR(soh.OrderDate),soh.SalesOrderID ,p.LastName, p.FirstName),

 CTE_maxtotal_order
AS
(select csoy.year, 
		max(csoy.sumorder) as total
from CTE_sumorder_for_year csoy
group by grouping sets (csoy.year))

select cto.year, csoy.SalesOrderID, csoy.LastName, csoy.FirstName, cto.total  
from CTE_maxtotal_order cto join CTE_sumorder_for_year csoy
on csoy.year= cto.year
where  csoy.sumorder=cto.total


  --7. number order every M for YEAR. P.VOTE 

Select MM,[2011], [2012], [2013], [2014]
from (Select year(OrderDate)  as yy , MONTH(OrderDate) as MM, salesorderid
		from sales.SalesOrderHeader)  soh
PIVOT(count(salesorderid) for yy in ([2011], [2012], [2013], [2014])) rrr 
order by MM

--8. select sum(unitprice*orders) for each month in year and sum(unitprice*orders) for each year.
--rows for 'money' 
 -- CTE ב
 -- כדי לסכום כל שנה בנוסף לכל חודש, נחלק את הקבוצות סיכום לפי group by rollup
WITH CTE_totalorders
AS
(
select  sales.YEAR,
		sales.MONTH,
		sales.sum_price ,
		sum(sales.sum_price) over (partition by sales.YEAR 
		order by sales.YEAR ,Sales.MONTH rows between unbounded preceding and current row) as [money]
from	(select year(ssoh.orderdate) AS [YEAR], 
				month (ssoh.orderdate) AS [MONTH], 
				round (sum(ssod.UnitPrice *(1-ssod.UnitPriceDiscount)*ssod.OrderQty),2) as [sum_price]
			from sales.SalesOrderHeader ssoh join sales.SalesOrderDetail ssod
			on ssoh.SalesOrderID = ssod.SalesOrderID
			group by rollup (year(ssoh.orderdate), month (ssoh.orderdate))) as [sales]  
			where sales.YEAR is not null and sales.MONTH is not null	   
),

CTE_SUMORDERSYEAR
as
(select * 
from CTE_totalorders cto
group by rollup ((cto.YEAR),(cto.MONTH, cto.sum_price, cto.money))
)
select  csyo.YEAR AS [Year],
		ISNULL (CAST((csyo.month) as char (20) ),'grand_total') as [MONTH],
		csyo.sum_price as [sum price],
		ISNULL (csyo.money, LAG (csyo.money) OVER (ORDER BY csyo.YEAR)) AS [Money]
		from CTE_SUMORDERSYEAR csyo
		where csyo.YEAR is not null

-- 9.employees order by hiredate in each department from the new to veteran
-- DEPARTMENT NAME from  HED.NAME and not from HRE.JOBTITLE 
-- if NULL so we can see the most veteran employee on this department
-- where  enddate is null and then u can get just the employees they steel work.  


select	HRD.Name as [Department_Name],	
		sc.PersonID as [Employees_ID], 
		PP.FirstName + ' ' + PP.LastName as [EmployeesFullName] ,
		HRE.HireDate,
		DATEDIFF(MM,HRE.HireDate, GETDATE()) as [seniority],
		LAG(PP.FirstName +' '+ PP.LastName,1,null) OVER (partition by HRD.Name  ORDER BY HRE.HireDate) as [PreviuseEmpName],
		LAG (HRE.HireDate,1,null) OVER ( partition by HRD.Name ORDER BY HRE.HireDate) AS [PreviusEmpHDate],
		DATEDIFF(DD ,LAG (HRE.HireDate,1, null)OVER (PARTITION BY hrd.Name ORDER BY HRE.HireDate),HRE.HireDate ) as [DiffDays]
from   person.Person PP 
join HumanResources.Employee HRE on HRE.BusinessEntityID= PP.BusinessEntityID
join HumanResources.EmployeeDepartmentHistory HREDH on HRE.BusinessEntityID = HREDH.BusinessEntityID
join HumanResources.Department HRD on HREDH.DepartmentID= HRD.DepartmentID
join Sales.Customer sc on sc.PersonID = pp.BusinessEntityID
where HREDH.EndDate is null
GROUP BY HRD.Name,sc.PersonID, PP.FirstName,PP.LastName,HRE.HireDate , HREDH.DepartmentID    
order by Department_Name ,HRE.HireDate desc
 


--10. employees deatels in the same department with the same  hire date
--  use STUFF / STRING_AGG to get all employees that hire date on the same day together


with cte_hiredateemployees
as
(
select	Seniorityemployee.HireDate,
		Seniorityemployee.DepartmentID,
		Seniorityemployee.PersonID,
		Seniorityemployee.fullname
from (SELECT	HRE.HireDate as [HireDate], 
				HRD.DepartmentID as [DepartmentID],
				SC.PersonID as [PersonID],
				pp.LastName +' '+ pp.FirstName as [fullname]				
FROM HumanResources.Employee HRE 
join person.Person PP on HRE.BusinessEntityID= PP.BusinessEntityID
join Sales.Customer SC on pp.BusinessEntityID= SC.PersonID
join HumanResources.EmployeeDepartmentHistory HREDH on HRE.BusinessEntityID = HREDH.BusinessEntityID 
join  HumanResources.Department HRD on HREDH.DepartmentID = HRD.DepartmentID
where HireDate = HireDate and HRD.DepartmentID = HREDH.DepartmentID and HREDH.EndDate is null
GROUP BY HRE.HireDate,sc.PersonID,pp.LastName,pp.FirstName, HRD.DepartmentID )
 as [Seniorityemployee] 
 ),

CTE_detailsemployees
as
(select chde.HireDate,
		chde.DepartmentID, 
		CONVERT(varchar (120),
		concat (chde.PersonID,' ' , chde.fullname))as [a]			
from cte_hiredateemployees chde 
group by rollup (chde.HireDate), (chde.DepartmentID), (chde.PersonID) ,(chde.fullname )
)

select	cde.HireDate,
		cde.DepartmentID,
		STRING_AGG(cde.a,(','))as [A]
from CTE_detailsemployees cde
where cde.HireDate is not null
group by cde.HireDate,cde.DepartmentID
order by cde.HireDate
