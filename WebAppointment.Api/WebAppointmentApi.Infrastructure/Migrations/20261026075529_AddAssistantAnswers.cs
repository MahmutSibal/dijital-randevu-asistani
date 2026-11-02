using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace WebAppointmentApi.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddAssistantAnswers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AssistantAnswers",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    QuestionKey = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ContextHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Question = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    Answer = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Model = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    HitCount = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    LastHitAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    TenantId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AssistantAnswers", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AssistantAnswers_TenantId_ContextHash_QuestionKey",
                table: "AssistantAnswers",
                columns: new[] { "TenantId", "ContextHash", "QuestionKey" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AssistantAnswers");
        }
    }
}
