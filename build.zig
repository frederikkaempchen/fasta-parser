const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("fasta_parser", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);

    addExamples(b, target, optimize, mod);
}

fn addExamples(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, root: *std.Build.Module) void {
    // list all examples here
    const examples = [_]struct { name: []const u8, file: []const u8 }{
        .{ .name = "comptime_file", .file = "examples/embed_file_comptime.zig" },
        .{ .name = "runtime_read", .file = "examples/read_at_runtime.zig" },
    };

    const build_all_step = b.step("examples", "Build all examples");

    const run_all_step = b.step("run-examples", "Run all examples");

    for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.file),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "fasta_parser", .module = root },
                },
            }),
        });

        // building all examples depends on building this example
        const install_step = b.addInstallArtifact(exe, .{});
        build_all_step.dependOn(&install_step.step);

        // building this example as extra command
        const build_step = b.step(b.fmt("example-{s}", .{example.name}), b.fmt("Build the {s} example", .{example.name}));
        build_step.dependOn(&install_step.step);

        // running and example depends on the example executable
        const run_cmd = b.addRunArtifact(exe);

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        run_all_step.dependOn(&run_cmd.step);

        // enable running only one example
        const run_step = b.step(b.fmt("run-example-{s}", .{example.name}), b.fmt("Run the {s} example", .{example.name}));
        run_step.dependOn(&run_cmd.step);
    }
}
