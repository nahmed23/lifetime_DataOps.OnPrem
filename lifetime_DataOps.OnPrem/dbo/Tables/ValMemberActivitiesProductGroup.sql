CREATE TABLE [dbo].[ValMemberActivitiesProductGroup] (
    [ValMemberActivitiesProductGroupID] SMALLINT     NOT NULL,
    [Description]                       VARCHAR (50) NULL,
    [SortOrder]                         SMALLINT     NULL,
    [InsertedDateTime]                  DATETIME     CONSTRAINT [DF_ValMemberActivitiesProductGroup_InsertedDateTime] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_ValMemberActivitiesProductGroup] PRIMARY KEY NONCLUSTERED ([ValMemberActivitiesProductGroupID] ASC)
);

