--MSSQL5429D
CREATE VIEW [dbo].[vClubProductPriceTax]
AS
SELECT        CP.ClubID, CP.ProductID, TR.TaxRateID, P.DepartmentID, P.Description AS ProductDescription, P.DisplayUIFlag, TR.TaxPercentage, CP.Price, VT.ValTaxTypeID, 
                         VT.Description AS TaxDescription, CP.ValCommissionableID, CP.SoldInPK, MT.MembershipTypeID, P.StartDate, P.EndDate, MT.ValUnitTypeID, 
                         VUT.Description AS ShortTermMembershipUnit, MT.MaxUnitType, P.ValRecurrentProductTypeID, P.CompletePackageFlag, P.AllowZeroDollarFlag, 
                         P.PackageProductFlag, P.SoldNotServicedFlag, P.ValProductStatusID, P.TipAllowedFlag, P.JrMemberDuesFlag, P.ConfirmMemberDataFlag, P.MedicalProductFlag, 
                         P.BundleProductFlag, P.PriceLockedFlag, P.ValEmployeeLevelTypeID, P.LTBuckEligible, P.ExcludeFromClubPOSFlag,P.AccessByPricePaidFlag
FROM            dbo.vClubProduct AS CP INNER JOIN
                         dbo.vProduct AS P ON CP.ProductID = P.ProductID LEFT OUTER JOIN
                         dbo.vClubProductTaxRate AS CPTR ON CP.ClubID = CPTR.ClubID AND CP.ProductID = CPTR.ProductID LEFT OUTER JOIN
                         dbo.vTaxRate AS TR ON TR.TaxRateID = CPTR.TaxRateID LEFT OUTER JOIN
                         dbo.vValTaxType AS VT ON VT.ValTaxTypeID = TR.ValTaxTypeID LEFT OUTER JOIN
                         dbo.vMembershipType AS MT ON CP.ProductID = MT.ProductID LEFT OUTER JOIN
                         dbo.vValUnitType AS VUT ON VUT.ValUnitTypeID = MT.ValUnitTypeID
WHERE        (CPTR.EndDate IS NULL) OR
                         (CPTR.EndDate >= GETDATE()) AND (CPTR.StartDate <= GETDATE())

