CREATE PROC dbo.procCognos_SNSStop (

	@StartDate DATETIME,
	@EndDate DATETIME,
	@RegionList VARCHAR(8000),
    @ClubIDList VARCHAR(8000)
	)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON
/*
DECLARE		@StartDate DATETIME = '1/1/2020'
DECLARE		@EndDate DATETIME = '4/30/2020' 
DECLARE		@RegionList VARCHAR(8000) = 'Messerli-Heartland'
DECLARE		@ClubIDList VARCHAR(8000) = '157|198'

SET		@StartDate  = '1/1/2020'
SET		@EndDate = '5/30/2020' 
SET		@RegionList  = 'Messerli-Heartland'
SET		@ClubIDList = '157|198'*/



IF OBJECT_ID('tempdb.dbo.#ClubID', 'U') IS NOT NULL
  DROP TABLE #ClubID;

Select ClubID, ClubName      
INTO #ClubID  
FROM vClub Club   
 JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%All Clubs%'
  JOIN vValRegion ValRegion
    ON Club.ValRegionID = ValRegion.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON ValRegion.Description = RegionList.Item
      OR @RegionList like '%All Regions%'
	WHERE Club.ClubID NOT IN (-1,99,100)
   AND Club.ClubID < 900

  ---- This returns all open packages for obsolete products 
IF OBJECT_ID('tempdb.dbo.#ProductPackageMembers', 'U') IS NOT NULL
  DROP TABLE #ProductPackageMembers;
  
SELECT Club.ClubID,
       Club.ClubName,
	   PKG.PackageID, 
	   PKG.MemberID,
          Product.ProductID,
          Product.Description,
		  PKG.EmployeeID AS SellingEmployeeID,
		  Salecommission.EmployeeID AS SaleCommissionEmployee,
		  PKGS.DeliveredEmployeeID
INTO #ProductPackageMembers  -------Select * from #ProductPackageMembers
       FROM vPackage PKG    
JOIN #ClubID Club    
   ON PKG.ClubID = Club.ClubID   
JOIN  [dbo].[vPackageSession]  PKGS
   ON PKG.PackageID = PKGS.PackageID 
JOIN vProduct   Product 
   ON PKG.ProductID = Product.ProductID  
JOIN vSaleCommission Salecommission
   ON PKG.TranItemID = Salecommission.[TranItemID]
WHERE PKG.SessionsLeft <> 0
 
 AND (PKGS.DeliveredEmployeeID <> PKG.EmployeeID
        OR  Product.description like '%SNS%')
GROUP BY Club.ClubID,   
       Club.ClubName,
	   PKG.PackageID, 
		  PKG.MemberID,
          Product.ProductID,
          Product.Description,
		  PKG.EmployeeID,
		  Salecommission.EmployeeID, 
		  PKGS.DeliveredEmployeeID

IF OBJECT_ID('tempdb.dbo.#RecurrentMembers', 'U') IS NOT NULL
  DROP TABLE #RecurrentMembers;
 ---- Of the people who have open packages for obsolete products,
 ---- this returns the ones how have an active recurrent product "scheduled" to charge monthly
 ---- and what those recurrent products are
Select 
		ROW_NUMBER() OVER (ORDER BY MRP.MemberID) RowNum,
		MRP.MemberID,
		M.FirstName +' '+ M.LastName 'MemberName',
       Member.ProductID AS SNSPackageProductID,
	   Member.Description AS SNSPackageProduct,
	   	Member.SellingEmployeeID,
		Member.DeliveredEmployeeID,
	   RecurrentProduct.ProductID AS RecurrentProductID,
	   RecurrentProduct.Description AS RecurrentProduct,
	   MRP.ActivationDate AS RecurrentProductActiviationDate,
	   MRP.TerminationDate AS RecurrentProductTerminationDate
	   --MRP.ProductHoldBeginDate AS RecurrentProductHoldStartDate,
       --MRP.ProductHoldEndDate AS RecurrentProductHoldEndDate
	   INTO #RecurrentMembers
	FROM vMembershipRecurrentProduct MRP
  JOIN #ProductPackageMembers Member
    ON MRP.MemberID = Member.MemberID
  JOIN vProduct  RecurrentProduct
    ON MRP.ProductID = RecurrentProduct.ProductID
	JOIN vMember M
	ON MRP.MemberID=M.MemberID
	Where (MRP.TerminationDate IS Null OR MRP.TerminationDate > Getdate()) AND RecurrentProduct.ProductID <> 3504


--Doing a self join to find the old products and the termination date of the old product and match with the new product and the new activation date one it is transferring to 
SELECT
a.MemberID
,a.MemberName
,a.SNSPackageProduct
,b.RecurrentProductTerminationDate as 'EFTEndDate'
,a.DeliveredEmployeeID as 'NewCommissionableEmployee'
,GETDATE() as HeaderRunDateTime


FROM #RecurrentMembers a
JOIN #RecurrentMembers b
ON a.MemberID=b.MemberID
AND b.RecurrentProductID=b.SNSPackageProductID
AND b.RecurrentProductID=a.SNSPackageProductID
WHERE
  (DATEDIFF(D,b.RecurrentProductTerminationDate,a.RecurrentProductActiviationDate)=2 OR DATEDIFF(D,b.RecurrentProductTerminationDate,a.RecurrentProductActiviationDate)=1)  
  AND a.SNSPackageProduct<>a.RecurrentProduct
  AND (b.RecurrentProductTerminationDate > @StartDate AND b.RecurrentProductTerminationDate < @EndDate)

  GROUP BY
 a.MemberID
,a.MemberName
,a.SNSPackageProduct
,b.RecurrentProductTerminationDate
,a.DeliveredEmployeeID


Order by a.MemberID,a.SNSPackageProduct

END
