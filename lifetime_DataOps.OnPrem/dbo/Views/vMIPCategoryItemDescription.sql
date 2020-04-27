

CREATE VIEW dbo.vMIPCategoryItemDescription AS 
SELECT MIPCategoryItemID,MCI.ValMIPCategoryID,VMC.Description Category,MCI.ValMIPSubCategoryID, VMS.Description SubCategory,MCI.ValMIPItemID,
       VMI.Description Item,MCI.ActiveFlag,MCI.AllowCommentFlag,MCI.SortOrder
FROM vMIPCategoryItem MCI JOIN vValMIPCategory VMC ON MCI.ValMIPCategoryID = VMC.ValMIPCategoryID
                         LEFT JOIN vValMIPSubCategory VMS ON MCI.ValMIPSubCategoryID = VMS.ValMIPSubCategoryID
                         JOIN vValMIPItem VMI ON MCI.ValMIPItemID = VMI.ValMIPItemID


