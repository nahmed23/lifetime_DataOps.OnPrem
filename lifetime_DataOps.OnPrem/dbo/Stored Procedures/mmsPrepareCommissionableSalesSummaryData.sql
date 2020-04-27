


CREATE  PROC mmsPrepareCommissionableSalesSummaryData
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- This procedure will prepare Commissionable Sales Summary data for Commissionable Sales reports
-- 06/04/2010 MLL Added load of Automated Refunds
-- 06/29/2010 MLL Added ItemDiscountAmount to load


--Only populate with data going back through the previous year
DECLARE @LastYear DATETIME
SET @LastYear = CONVERT(DATETIME,(CONVERT(VARCHAR(4),YEAR(GETDATE())-1) + '-01-01'))

DELETE MMSCommissionableSalesSummary
WHERE PostDateTime < @LastYear


--Set the number of days to go back and rebuild on a daily basis
DECLARE @DeleteTimeframe DATETIME
SET @DeleteTimeframe = DATEADD(DD,-40,CONVERT(DATETIME,CONVERT(VARCHAR(11),GETDATE()))) --40 days old

--AT 4AM DELETE AND REPOPULATE THE TABLE.
   IF DATEPART(HH,GETDATE()) = 4
   BEGIN

		--Delete the current entries in the table going back xx days
        DELETE MMSCommissionableSalesSummary
		WHERE PostDateTime >= @DeleteTimeframe
 
		--Rebuild the table
        INSERT INTO vMMSCommissionableSalesSummary(ClubID,ClubName,SalesPersonFirstName,SalesPersonLastName,
                                                   SalesEmployeeID,ReceiptNumber,MemberID,MemberFirstName,
                                                   MemberLastName,CorporateCode,MembershipTypeID,MembershipTypeDescription,
                                                   ItemAmount,Quantity,CommissionCount,PostDateTime,UTCPostDateTime,
                                                   TranItemID,ValRegionID,RegionDescription,DepartmentID,
                                                   DeptDescription,ProductID,ProductDescription,AdvisorID,
						   AdvisorFirstName,AdvisorLastName,ItemDiscountAmount)
        SELECT C.ClubID,C.ClubName, E.FirstName SalesPersonFirstName, E.LastName SalesPersonLastName,
               E.EmployeeID SalesEmployeeID, MMST.ReceiptNumber, MMST.MemberID,
               M.FirstName, M.LastName, C2.CorporateCode,MST.MembershipTypeID,
               P.Description MembershipTypeDescription, TI.ItemAmount, TI.Quantity,
               CSC.CommissionCount Count2, MMST.PostDateTime, MMST.UTCPostDateTime,TI.TranItemID,VR.ValRegionID,
               VR.Description RegionDescription, D.DepartmentID,D.Description DeptDescription, 
               P2.ProductID,P2.Description ProductDescription,E2.EmployeeID AdvisorID,
	       E2.FirstName AdvisorFirstName,E2.LastName AdvisorLastName, TI.ItemDiscountAmount
       FROM dbo.vMember M
            JOIN dbo.vMMSTranNonArchive MMST
               ON M.MemberID = MMST.MemberID
            JOIN dbo.vMembership MS
               ON MS.MembershipID = MMST.MembershipID
            JOIN dbo.vClub C
               ON MMST.ClubID = C.ClubID
            JOIN dbo.vValRegion VR
               ON C.ValRegionID = VR.ValRegionID
            JOIN dbo.vTranItem TI
               ON MMST.MMSTranID = TI.MMSTranID
            JOIN dbo.vProduct P2
               ON TI.ProductID = P2.ProductID
            JOIN dbo.vSaleCommission SC
               ON TI.TranItemID = SC.TranItemID
            JOIN dbo.vEmployee E
               ON SC.EmployeeID = E.EmployeeID
            JOIN dbo.vMembershipType MST
               ON MS.MembershipTypeID = MST.MembershipTypeID
            JOIN dbo.vProduct P
               ON MST.ProductID = P.ProductID
            JOIN dbo.vCommissionSplitCalc CSC
               ON TI.TranItemID = CSC.TranItemID
            JOIN dbo.vDepartment D
               ON P2.DepartmentID = D.DepartmentID
            LEFT JOIN dbo.vCompany C2
               ON C2.CompanyID = MS.CompanyID
	    LEFT JOIN dbo.vEmployee E2
	       ON MS.AdvisorEmployeeID = E2.EmployeeID
       WHERE MMST.TranVoidedID IS NULL 
		 AND MMST.PostDateTime >= @DeleteTimeframe

--Automated Refund Logic

SELECT 
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubID
                 ELSE OriginalTranClub.ClubID
       END AS ClubID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubName
                 ELSE OriginalTranClub.ClubName
       END AS ClubName,
       MIN(SC.SaleCommissionID) AS PrimarySalesPersonSalesCommissionID,
       MMST.ReceiptNumber, 
       OriginalM.MemberID, 
       OriginalM.FirstName AS MemberFirstName, 
       OriginalM.LastName AS MemberLastName, 
       CO.CorporateCode, 
       MS.MembershipTypeID,
       MSP.Description AS MembershipTypeDescription, 
       TI.ItemAmount,
       TI.Quantity, 
       1 AS CommissionCount,
       MMST.PostDateTime, 
       MMST.UTCPostDateTime,
       TI.TranItemID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ValRegionID
                 ELSE OriginalTranClub.ValRegionID
       END AS ValRegionID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipRegion.Description 
                 ELSE OriginalRegion.Description 
       END AS RegionDescription,
       D.DepartmentID,
       D.Description AS DeptDescription,
       P.ProductID,
       P.Description AS ProductDescription,
       MembershipAdvisor.EmployeeID AS AdvisorID, 
       MembershipAdvisor.FirstName AS AdvisorFirstName, 
       MembershipAdvisor.LastName AS AdvisorLastName,
       TI.ItemDiscountAmount
INTO #AutomatedRefundDetail4AM
  FROM vMMSTran MMST
  JOIN vTranItem TI
    ON MMST.MMSTranID = TI.MMSTranID
  JOIN vProduct P
    ON TI.ProductID = P.ProductID
  JOIN vTranItemRefund TIR
    ON TIR.TranItemID = TI.TranItemID
  JOIN vTranItem OriginalTI
    ON OriginalTI.TranItemID = TIR.OriginalTranItemID
  JOIN vSaleCommission SC
    ON OriginalTI.TranItemID = SC.TranItemID
  JOIN vMMSTran OriginalMMST
    ON OriginalMMST.MMSTranID = OriginalTI.MMSTranID
  JOIN vClub OriginalTranClub
    ON OriginalTranClub.ClubID = OriginalMMST.ClubID
  JOIN vValRegion OriginalRegion
    ON OriginalRegion.ValRegionID = OriginalTranClub.ValRegionID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vClub MembershipClub
    ON MembershipClub.ClubID = MS.ClubID
  JOIN vValRegion MembershipRegion
    ON MembershipRegion.ValRegionID = MembershipClub.ValRegionID
  LEFT JOIN vCompany CO
    ON CO.CompanyID = MS.CompanyID
  JOIN vMembershipType MT
    ON MT.MembershipTypeID = MS.MembershipTYpeID
  JOIN vProduct MSP
    ON MSP.ProductID = MT.ProductID
  JOIN vMember OriginalM
    ON OriginalM.MemberID = OriginalMMST.MemberID
  LEFT JOIN vEmployee MembershipAdvisor
    ON MembershipAdvisor.EmployeeID = MS.AdvisorEmployeeID
  JOIN vDepartment D
    ON D.DepartmentID = P.DepartmentID
 WHERE MMST.PostDateTime >= @DeleteTimeframe
   AND MMST.ValTranTypeID = 5
 GROUP BY 
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubID
                 ELSE OriginalTranClub.ClubID
       END,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubName
                 ELSE OriginalTranClub.ClubName
       END,
       MMST.ReceiptNumber, 
       OriginalM.MemberID, 
       OriginalM.FirstName, 
       OriginalM.LastName, 
       CO.CorporateCode, 
       MS.MembershipTypeID,
       MSP.Description,
       TI.ItemAmount,
       TI.Quantity, 
       MMST.PostDateTime, 
       MMST.UTCPostDateTime,
       TI.TranItemID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ValRegionID
                 ELSE OriginalTranClub.ValRegionID
       END,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipRegion.Description 
                 ELSE OriginalRegion.Description 
       END,
       D.DepartmentID,
       D.Description,
       P.ProductID,
       P.Description,
       MembershipAdvisor.EmployeeID, 
       MembershipAdvisor.FirstName, 
       MembershipAdvisor.LastName,
       TI.ItemDiscountAmount

        INSERT INTO vMMSCommissionableSalesSummary(ClubID,ClubName,SalesPersonFirstName,SalesPersonLastName,
                                                   SalesEmployeeID,ReceiptNumber,MemberID,MemberFirstName,
                                                   MemberLastName,CorporateCode,MembershipTypeID,MembershipTypeDescription,
                                                   ItemAmount,Quantity,CommissionCount,PostDateTime,UTCPostDateTime,
                                                   TranItemID,ValRegionID,RegionDescription,DepartmentID,
                                                   DeptDescription,ProductID,ProductDescription,AdvisorID,
						   AdvisorFirstName,AdvisorLastName,ItemDiscountAmount)
SELECT ARD.ClubID,
       ARD.ClubName,
       E.FirstName AS SalesPersonFirstName,
       E.LastName AS SalesPersonLastName,
       E.EmployeeID AS SalesEmployeeID,
       ARD.ReceiptNumber,
       ARD.MemberID,
       ARD.MemberFirstName,
       ARD.MemberLastName,
       ARD.CorporateCode,
       ARD.MembershipTypeID,
       ARD.MembershipTypeDescription,
       ARD.ItemAmount,
       ARD.Quantity,
       ARD.CommissionCount,
       ARD.PostDateTime,
       ARD.UTCPostDateTime,
       ARD.TranItemID,
       ARD.ValRegionID,
       ARD.RegionDescription,
       ARD.DepartmentID,
       ARD.DeptDescription,
       ARD.ProductID,
       ARD.ProductDescription,
       ARD.AdvisorID,
       ARD.AdvisorFirstName,
       ARD.AdvisorLastName,
       ARD.ItemDiscountAmount
  FROM #AutomatedRefundDetail4AM ARD
  JOIN vSaleCommission SC
    ON SC.SaleCommissionID = ARD.PrimarySalesPersonSalesCommissionID
  JOIN vEmployee E
    on E.EmployeeID = SC.EmployeeID

DROP TABLE #AutomatedRefundDetail4AM

   END
   ELSE
   BEGIN

        --get max postdatetime from the summary table.
	DECLARE @UTCPostDateTime DATETIME
    DECLARE @VoidedDateTime DATETIME
	
-- 6/4/2010 MLL Removed truncate of UTCPostDateTime as truncate could cause records to be re-inserted
	SELECT @UTCPostDateTime = MAX(UTCPostDateTime) --CONVERT(DATETIME,CONVERT(VARCHAR,MAX(UTCPostDateTime),110),110)
	FROM vMMSCommissionableSalesSummary

        SET @VoidedDateTime = DATEADD(DD,-1,@UTCPostDateTime)
 
       --get all commissionable sales that were created on or after the max postdatetime

	SELECT C.ClubID,C.ClubName, E.FirstName SalesPersonFirstName, E.LastName SalesPersonLastName,
	       E.EmployeeID SalesEmployeeID, MMST.ReceiptNumber, MMST.MemberID,
	       M.FirstName, M.LastName, C2.CorporateCode,MST.MembershipTypeID,
	       P.Description MembershipTypeDescription, TI.ItemAmount, TI.Quantity,
	       CSC.CommissionCount Count2, MMST.PostDateTime, MMST.UTCPostDateTime,TI.TranItemID,VR.ValRegionID,
	       VR.Description RegionDescription, D.DepartmentID,D.Description DeptDescription, 
	       P2.ProductID,P2.Description ProductDescription,E2.EmployeeID AdvisorID,
	       E2.FirstName AdvisorFirstName,E2.LastName AdvisorLastName,TI.ItemDiscountAmount
	INTO #tmpCommissionableSalesSummary
	  FROM dbo.vMember M
	  JOIN dbo.vMMSTranNonArchive MMST
	       ON M.MemberID = MMST.MemberID
	  JOIN dbo.vMembership MS
	       ON MS.MembershipID = MMST.MembershipID
	  JOIN dbo.vClub C
	       ON MMST.ClubID = C.ClubID
	  JOIN dbo.vValRegion VR
	       ON C.ValRegionID = VR.ValRegionID
	  JOIN dbo.vTranItem TI
	       ON MMST.MMSTranID = TI.MMSTranID
	  JOIN dbo.vProduct P2
	       ON TI.ProductID = P2.ProductID
	  JOIN dbo.vSaleCommission SC
	       ON TI.TranItemID = SC.TranItemID
	  JOIN dbo.vEmployee E
	       ON SC.EmployeeID = E.EmployeeID
	  JOIN dbo.vMembershipType MST
	       ON MS.MembershipTypeID = MST.MembershipTypeID
	  JOIN dbo.vProduct P
	       ON MST.ProductID = P.ProductID
	  JOIN dbo.vCommissionSplitCalc CSC
	       ON TI.TranItemID = CSC.TranItemID
	  JOIN dbo.vDepartment D
	       ON P2.DepartmentID = D.DepartmentID
	  LEFT JOIN dbo.vCompany C2
	       ON C2.CompanyID = MS.CompanyID
      LEFT JOIN dbo.vEmployee E2
           ON MS.AdvisorEmployeeID = E2.EmployeeID
-- 6/4/2010 MLL Removed truncate of UTCPostDateTime as truncate could cause records to be re-inserted
	 WHERE MMST.TranVoidedID IS NULL AND MMST.UTCPostDateTime > @UTCPostDateTime -->= @UTCPostDateTime
	   AND MMST.PostDateTime >= @DeleteTimeframe

        --insert into MMSCommissionableSalesSummary all new Commissionable Sales
	INSERT INTO vMMSCommissionableSalesSummary(ClubID,ClubName,SalesPersonFirstName,SalesPersonLastName,
	                                          SalesEmployeeID,ReceiptNumber,MemberID,MemberFirstName,
	                                          MemberLastName,CorporateCode,MembershipTypeID,MembershipTypeDescription,
	                                          ItemAmount,Quantity,CommissionCount,PostDateTime,UTCPostDateTime,
	                                          TranItemID,ValRegionID,RegionDescription,DepartmentID,
	                                          DeptDescription,ProductID,ProductDescription,AdvisorID,
						  AdvisorFirstName,AdvisorLastName,ItemDiscountAmount)
	SELECT TCS.ClubID,TCS.ClubName, TCS.SalesPersonFirstName, TCS.SalesPersonLastName,TCS.SalesEmployeeID, TCS.ReceiptNumber, TCS.MemberID,
	       TCS.FirstName, TCS.LastName, TCS.CorporateCode,TCS.MembershipTypeID,TCS.MembershipTypeDescription, TCS.ItemAmount, TCS.Quantity,
	       TCS.Count2, TCS.PostDateTime, TCS.PostDateTime,TCS.TranItemID,TCS.ValRegionID,TCS.RegionDescription, TCS.DepartmentID,TCS.DeptDescription, 
	       TCS.ProductID,TCS.ProductDescription,TCS.AdvisorID,TCS.AdvisorFirstName,TCS.AdvisorLastName,TCS.ItemDiscountAmount
	FROM #tmpCommissionableSalesSummary TCS
	     LEFT JOIN vMMSCommissionableSalesSummary CS ON TCS.TranItemID = CS.TranItemID
	WHERE CS.TranItemID IS NULL
	DROP TABLE #tmpCommissionableSalesSummary

--Automated Refund Logic

SELECT 
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubID
                 ELSE OriginalTranClub.ClubID
       END AS ClubID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubName
                 ELSE OriginalTranClub.ClubName
       END AS ClubName,
       MIN(SC.SaleCommissionID) AS PrimarySalesPersonSalesCommissionID,
       MMST.ReceiptNumber, 
       OriginalM.MemberID, 
       OriginalM.FirstName AS MemberFirstName, 
       OriginalM.LastName AS MemberLastName, 
       CO.CorporateCode, 
       MS.MembershipTypeID,
       MSP.Description AS MembershipTypeDescription, 
       TI.ItemAmount,
       TI.Quantity, 
       1 AS CommissionCount,
       MMST.PostDateTime, 
       MMST.UTCPostDateTime,
       TI.TranItemID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ValRegionID
                 ELSE OriginalTranClub.ValRegionID
       END AS ValRegionID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipRegion.Description 
                 ELSE OriginalRegion.Description 
       END AS RegionDescription,
       D.DepartmentID,
       D.Description AS DeptDescription,
       P.ProductID,
       P.Description AS ProductDescription,
       MembershipAdvisor.EmployeeID AS AdvisorID, 
       MembershipAdvisor.FirstName AS AdvisorFirstName, 
       MembershipAdvisor.LastName AS AdvisorLastName,
       TI.ItemDiscountAmount
INTO #AutomatedRefundDetail
  FROM vMMSTran MMST
  JOIN vTranItem TI
    ON MMST.MMSTranID = TI.MMSTranID
  JOIN vProduct P
    ON TI.ProductID = P.ProductID
  JOIN vTranItemRefund TIR
    ON TIR.TranItemID = TI.TranItemID
  JOIN vTranItem OriginalTI
    ON OriginalTI.TranItemID = TIR.OriginalTranItemID
  JOIN vSaleCommission SC
    ON OriginalTI.TranItemID = SC.TranItemID
  JOIN vMMSTran OriginalMMST
    ON OriginalMMST.MMSTranID = OriginalTI.MMSTranID
  JOIN vClub OriginalTranClub
    ON OriginalTranClub.ClubID = OriginalMMST.ClubID
  JOIN vValRegion OriginalRegion
    ON OriginalRegion.ValRegionID = OriginalTranClub.ValRegionID
  JOIN vMembership MS
    ON MS.MembershipID = MMST.MembershipID
  JOIN vClub MembershipClub
    ON MembershipClub.ClubID = MS.ClubID
  JOIN vValRegion MembershipRegion
    ON MembershipRegion.ValRegionID = MembershipClub.ValRegionID
  LEFT JOIN vCompany CO
    ON CO.CompanyID = MS.CompanyID
  JOIN vMembershipType MT
    ON MT.MembershipTypeID = MS.MembershipTYpeID
  JOIN vProduct MSP
    ON MSP.ProductID = MT.ProductID
  JOIN vMember OriginalM
    ON OriginalM.MemberID = OriginalMMST.MemberID
  LEFT JOIN vEmployee MembershipAdvisor
    ON MembershipAdvisor.EmployeeID = MS.AdvisorEmployeeID
  JOIN vDepartment D
    ON D.DepartmentID = P.DepartmentID
-- 6/4/2010 MLL Removed truncate of UTCPostDateTime as truncate could cause records to be re-inserted
 WHERE MMST.TranVoidedID IS NULL AND MMST.UTCPostDateTime > @UTCPostDateTime -->= @UTCPostDateTime
   AND MMST.PostDateTime >= @DeleteTimeframe
   AND MMST.ValTranTypeID = 5
 GROUP BY 
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubID
                 ELSE OriginalTranClub.ClubID
       END,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ClubName
                 ELSE OriginalTranClub.ClubName
       END,
       MMST.ReceiptNumber, 
       OriginalM.MemberID, 
       OriginalM.FirstName, 
       OriginalM.LastName, 
       CO.CorporateCode, 
       MS.MembershipTypeID,
       MSP.Description,
       TI.ItemAmount,
       TI.Quantity, 
       MMST.PostDateTime, 
       MMST.UTCPostDateTime,
       TI.TranItemID,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipClub.ValRegionID
                 ELSE OriginalTranClub.ValRegionID
       END,
       CASE MMST.ReasonCodeID
            WHEN 108
                 THEN MembershipRegion.Description 
                 ELSE OriginalRegion.Description 
       END,
       D.DepartmentID,
       D.Description,
       P.ProductID,
       P.Description,
       MembershipAdvisor.EmployeeID, 
       MembershipAdvisor.FirstName, 
       MembershipAdvisor.LastName,
       TI.ItemDiscountAmount

        INSERT INTO vMMSCommissionableSalesSummary(ClubID,ClubName,SalesPersonFirstName,SalesPersonLastName,
                                                   SalesEmployeeID,ReceiptNumber,MemberID,MemberFirstName,
                                                   MemberLastName,CorporateCode,MembershipTypeID,MembershipTypeDescription,
                                                   ItemAmount,Quantity,CommissionCount,PostDateTime,UTCPostDateTime,
                                                   TranItemID,ValRegionID,RegionDescription,DepartmentID,
                                                   DeptDescription,ProductID,ProductDescription,AdvisorID,
						   AdvisorFirstName,AdvisorLastName,ItemDiscountAmount)
SELECT ARD.ClubID,
       ARD.ClubName,
       E.FirstName AS SalesPersonFirstName,
       E.LastName AS SalesPersonLastName,
       E.EmployeeID AS SalesEmployeeID,
       ARD.ReceiptNumber,
       ARD.MemberID,
       ARD.MemberFirstName,
       ARD.MemberLastName,
       ARD.CorporateCode,
       ARD.MembershipTypeID,
       ARD.MembershipTypeDescription,
       ARD.ItemAmount,
       ARD.Quantity,
       ARD.CommissionCount,
       ARD.PostDateTime,
       ARD.UTCPostDateTime,
       ARD.TranItemID,
       ARD.ValRegionID,
       ARD.RegionDescription,
       ARD.DepartmentID,
       ARD.DeptDescription,
       ARD.ProductID,
       ARD.ProductDescription,
       ARD.AdvisorID,
       ARD.AdvisorFirstName,
       ARD.AdvisorLastName,
       ARD.ItemDiscountAmount
  FROM #AutomatedRefundDetail ARD
  JOIN vSaleCommission SC
    ON SC.SaleCommissionID = ARD.PrimarySalesPersonSalesCommissionID
  JOIN vEmployee E
    on E.EmployeeID = SC.EmployeeID

DROP TABLE #AutomatedRefundDetail

        --DELETE VOIDED TRANSACTIONS
        DELETE vMMSCommissionableSalesSummary
        FROM vMMSCommissionableSalesSummary CSS
             JOIN vTranItem TI ON CSS.TranItemID = TI.TranItemID
             JOIN vMMSTranNonArchive MT ON TI.MMSTranID = MT.MMSTranID
             JOIN vTranVoided TV ON MT.TranVoidedID = TV.TranVoidedID
        WHERE TV.VoidDateTime >= @VoidedDateTime
   END


END
