using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace WebAppointmentApi.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddLoginEventsKvkkAndDocuments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "KvkkConsentAtUtc",
                table: "Users",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "KvkkConsentVersion",
                table: "Users",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AppointmentDocuments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    AppointmentId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    IssuedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    PayloadJson = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AppointmentDocuments", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "LoginEvents",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    Success = table.Column<bool>(type: "bit", nullable: false),
                    IpAddress = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    Device = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LoginEvents", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AppointmentDocuments_Code",
                table: "AppointmentDocuments",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AppointmentDocuments_TenantId_AppointmentId",
                table: "AppointmentDocuments",
                columns: new[] { "TenantId", "AppointmentId" });

            migrationBuilder.CreateIndex(
                name: "IX_LoginEvents_TenantId_UserId_AtUtc",
                table: "LoginEvents",
                columns: new[] { "TenantId", "UserId", "AtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AppointmentDocuments");

            migrationBuilder.DropTable(
                name: "LoginEvents");

            migrationBuilder.DropColumn(
                name: "KvkkConsentAtUtc",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "KvkkConsentVersion",
                table: "Users");
        }
    }
}
