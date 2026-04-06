const std = @import("std");
const zbh = @import("zig_build_helper");
const build_zon = @import("build.zig.zon");

comptime {
    zbh.checkZigVersion("0.15.2");
}

const version = "4.7.1";
const version_parts = parseVersion(version);

const ToolDef = struct {
    name: []const u8,
    src: []const u8,
};

const core_tool_defs = [_]ToolDef{
    .{ .name = "fax2ps", .src = "tools/fax2ps.c" },
    .{ .name = "fax2tiff", .src = "tools/fax2tiff.c" },
    .{ .name = "pal2rgb", .src = "tools/pal2rgb.c" },
    .{ .name = "ppm2tiff", .src = "tools/ppm2tiff.c" },
    .{ .name = "raw2tiff", .src = "tools/raw2tiff.c" },
    .{ .name = "tiff2bw", .src = "tools/tiff2bw.c" },
    .{ .name = "tiff2pdf", .src = "tools/tiff2pdf.c" },
    .{ .name = "tiff2ps", .src = "tools/tiff2ps.c" },
    .{ .name = "tiff2rgba", .src = "tools/tiff2rgba.c" },
    .{ .name = "tiffcmp", .src = "tools/tiffcmp.c" },
    .{ .name = "tiffcp", .src = "tools/tiffcp.c" },
    .{ .name = "tiffcrop", .src = "tools/tiffcrop.c" },
    .{ .name = "tiffdither", .src = "tools/tiffdither.c" },
    .{ .name = "tiffdump", .src = "tools/tiffdump.c" },
    .{ .name = "tiffinfo", .src = "tools/tiffinfo.c" },
    .{ .name = "tiffmedian", .src = "tools/tiffmedian.c" },
    .{ .name = "tiffset", .src = "tools/tiffset.c" },
    .{ .name = "tiffsplit", .src = "tools/tiffsplit.c" },
};

const core_sources = &[_][]const u8{
    "libtiff/tif_aux.c",
    "libtiff/tif_close.c",
    "libtiff/tif_codec.c",
    "libtiff/tif_color.c",
    "libtiff/tif_compress.c",
    "libtiff/tif_dir.c",
    "libtiff/tif_dirinfo.c",
    "libtiff/tif_dirread.c",
    "libtiff/tif_dirwrite.c",
    "libtiff/tif_dumpmode.c",
    "libtiff/tif_error.c",
    "libtiff/tif_extension.c",
    "libtiff/tif_fax3.c",
    "libtiff/tif_fax3sm.c",
    "libtiff/tif_flush.c",
    "libtiff/tif_getimage.c",
    "libtiff/tif_hash_set.c",
    "libtiff/tif_luv.c",
    "libtiff/tif_lzw.c",
    "libtiff/tif_next.c",
    "libtiff/tif_ojpeg.c",
    "libtiff/tif_open.c",
    "libtiff/tif_packbits.c",
    "libtiff/tif_pixarlog.c",
    "libtiff/tif_predict.c",
    "libtiff/tif_print.c",
    "libtiff/tif_read.c",
    "libtiff/tif_strip.c",
    "libtiff/tif_swab.c",
    "libtiff/tif_thunder.c",
    "libtiff/tif_tile.c",
    "libtiff/tif_version.c",
    "libtiff/tif_warning.c",
    "libtiff/tif_write.c",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const zlib_mode = b.option(zbh.Dependencies.Mode, "zlib", "ZIP/Deflate support: static (bundled), linked (system), none (default: static)") orelse .static;
    const jpeg_mode = b.option(zbh.Dependencies.Mode, "jpeg", "JPEG support: static (bundled), linked (system), none (default: static)") orelse .static;
    const webp_mode = b.option(zbh.Dependencies.Mode, "webp", "WebP codec support is currently out of scope (must remain none)") orelse .none;
    const zstd_mode = b.option(zbh.Dependencies.Mode, "zstd", "ZSTD codec support is currently out of scope (must remain none)") orelse .none;
    const lzma_mode = b.option(zbh.Dependencies.Mode, "lzma", "LZMA codec support is currently out of scope (must remain none)") orelse .none;
    const jbig_mode = b.option(zbh.Dependencies.Mode, "jbig", "JBIG codec support is not implemented yet (must remain none)") orelse .none;
    const lerc_mode = b.option(zbh.Dependencies.Mode, "lerc", "LERC codec support is not implemented yet (must remain none)") orelse .none;
    const tools = b.option(bool, "tools", "Build core TIFF command-line tools (default: true)") orelse true;

    if (zstd_mode != .none) {
        @panic("-Dzstd is currently out of scope for this package. Use -Dzstd=none.");
    }
    if (lzma_mode != .none) {
        @panic("-Dlzma is currently out of scope for this package. Use -Dlzma=none.");
    }
    if (webp_mode != .none) {
        @panic("-Dwebp is currently out of scope for this package. Use -Dwebp=none.");
    }
    if (jbig_mode != .none) {
        @panic("-Djbig is currently out of scope for this package. Use -Djbig=none.");
    }
    if (lerc_mode != .none) {
        @panic("-Dlerc is currently out of scope for this package. Use -Dlerc=none.");
    }

    const has_zlib = zlib_mode != .none;
    const has_jpeg = jpeg_mode != .none;
    const has_webp = webp_mode != .none;
    const has_zstd = zstd_mode != .none;
    const has_lzma = lzma_mode != .none;
    const has_jbig = false;
    const has_lerc = false;

    const lib = buildLibrary(
        b,
        target,
        optimize,
        upstream,
        .static,
        zlib_mode,
        jpeg_mode,
        webp_mode,
        zstd_mode,
        lzma_mode,
        jbig_mode,
        lerc_mode,
    );
    b.installArtifact(lib);

    if (tools) {
        addTools(b, target, optimize, upstream, lib, has_zlib, has_jpeg, has_webp, has_zstd, has_lzma, has_jbig, has_lerc);
    }

    const ci_step = b.step("ci", "Build release archives for all targets");
    addCiTargets(b, ci_step);
}

fn addTools(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    upstream: *std.Build.Dependency,
    tiff_lib: *std.Build.Step.Compile,
    has_zlib: bool,
    has_jpeg: bool,
    has_webp: bool,
    has_zstd: bool,
    has_lzma: bool,
    has_jbig: bool,
    has_lerc: bool,
) void {
    const platform = zbh.Platform.detect(target.result);
    if (platform.is_windows) return;

    const tif_config_h = createTifConfigH(b, upstream, platform, has_zlib, has_jpeg, has_webp, has_zstd, has_lzma, has_jbig, has_lerc);
    const libport_config = createLibportConfigH(b, platform);
    const cflags = &[_][]const u8{"-w"};

    for (core_tool_defs) |tool| {
        const exe = b.addExecutable(.{
            .name = tool.name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        exe.addIncludePath(upstream.path("libtiff"));
        exe.addIncludePath(upstream.path("port"));
        exe.addIncludePath(libport_config.dirname());
        exe.addConfigHeader(tif_config_h);
        exe.addCSourceFile(.{ .file = upstream.path(tool.src), .flags = cflags });
        exe.linkLibrary(tiff_lib);
        exe.linkSystemLibrary("m");
        b.installArtifact(exe);
    }
}

pub fn buildLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    upstream: *std.Build.Dependency,
    linkage: std.builtin.LinkMode,
    zlib_mode: zbh.Dependencies.Mode,
    jpeg_mode: zbh.Dependencies.Mode,
    webp_mode: zbh.Dependencies.Mode,
    zstd_mode: zbh.Dependencies.Mode,
    lzma_mode: zbh.Dependencies.Mode,
    jbig_mode: zbh.Dependencies.Mode,
    lerc_mode: zbh.Dependencies.Mode,
) *std.Build.Step.Compile {
    const platform = zbh.Platform.detect(target.result);

    const zlib_dep: ?*std.Build.Step.Compile = if (zlib_mode == .static)
        if (b.lazyDependency("zlib", .{ .target = target, .optimize = optimize })) |dep|
            dep.artifact("z")
        else
            null
    else
        null;

    const jpeg_dep: ?*std.Build.Step.Compile = if (jpeg_mode == .static)
        if (b.lazyDependency("libjpeg_turbo", .{ .target = target, .optimize = optimize })) |dep|
            dep.artifact("jpeg")
        else
            null
    else
        null;

    const has_zlib = zlib_mode != .none;
    const has_jpeg = jpeg_mode != .none;
    const has_webp = webp_mode != .none;
    const has_zstd = zstd_mode != .none;
    const has_lzma = lzma_mode != .none;
    const has_jbig = jbig_mode != .none;
    const has_lerc = lerc_mode != .none;

    const tiffconf_h = createTiffconfH(b, platform, has_zlib, has_jpeg, has_webp, has_zstd, has_lzma, has_jbig, has_lerc);
    const tif_config_h = createTifConfigH(b, upstream, platform, has_zlib, has_jpeg, has_webp, has_zstd, has_lzma, has_jbig, has_lerc);
    const tiffvers_h = createTiffversH(b);

    const lib = b.addLibrary(.{
        .name = "tiff",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = linkage,
    });

    lib.addIncludePath(tiffconf_h.dirname());
    lib.addConfigHeader(tif_config_h);
    lib.addIncludePath(tiffvers_h.dirname());
    lib.addIncludePath(upstream.path("libtiff"));

    var flags = zbh.Flags.Builder.init(b.allocator);
    flags.append("-w");
    if (platform.is_windows) {
        flags.append("-D_O_RDONLY=0x0000");
        flags.append("-D_O_WRONLY=0x0001");
        flags.append("-D_O_RDWR=0x0002");
        flags.append("-D_O_CREAT=0x0100");
        flags.append("-D_O_TRUNC=0x0200");
        flags.append("-DO_RDONLY=_O_RDONLY");
        flags.append("-DO_WRONLY=_O_WRONLY");
        flags.append("-DO_RDWR=_O_RDWR");
        flags.append("-DO_CREAT=_O_CREAT");
        flags.append("-DO_TRUNC=_O_TRUNC");
    }

    lib.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = core_sources,
        .flags = flags.items(),
    });

    if (platform.is_windows) {
        lib.addCSourceFile(.{ .file = upstream.path("libtiff/tif_win32.c"), .flags = flags.items() });
    } else {
        lib.addCSourceFile(.{ .file = upstream.path("libtiff/tif_unix.c"), .flags = flags.items() });
    }

    if (has_zlib) {
        lib.addCSourceFile(.{ .file = upstream.path("libtiff/tif_zip.c"), .flags = flags.items() });
        if (zlib_dep) |z| {
            lib.linkLibrary(z);
        } else if (zlib_mode == .linked) {
            lib.linkSystemLibrary("z");
        }
    }

    if (has_jpeg) {
        lib.addCSourceFile(.{ .file = upstream.path("libtiff/tif_jpeg.c"), .flags = flags.items() });
        if (jpeg_dep) |j| {
            lib.linkLibrary(j);
        } else if (jpeg_mode == .linked) {
            lib.linkSystemLibrary("jpeg");
        }
    }

    if (has_webp) {
        lib.addCSourceFile(.{ .file = upstream.path("libtiff/tif_webp.c"), .flags = flags.items() });
        if (webp_mode == .linked) {
            lib.linkSystemLibrary("webp");
        }
    }

    if (has_zstd) {
        lib.addCSourceFile(.{ .file = upstream.path("libtiff/tif_zstd.c"), .flags = flags.items() });
        if (zstd_mode == .linked) {
            lib.linkSystemLibrary("zstd");
        }
    }

    if (has_lzma) {
        lib.addCSourceFile(.{ .file = upstream.path("libtiff/tif_lzma.c"), .flags = flags.items() });
        if (lzma_mode == .linked) {
            lib.linkSystemLibrary("lzma");
        }
    }

    if (has_jbig) {
        lib.addCSourceFile(.{ .file = upstream.path("libtiff/tif_jbig.c"), .flags = flags.items() });
    }

    if (has_lerc) {
        lib.addCSourceFile(.{ .file = upstream.path("libtiff/tif_lerc.c"), .flags = flags.items() });
    }

    if (!platform.is_windows) {
        lib.linkSystemLibrary("m");
    }

    lib.installHeader(upstream.path("libtiff/tiff.h"), "tiff.h");
    lib.installHeader(upstream.path("libtiff/tiffio.h"), "tiffio.h");
    lib.installHeader(tiffconf_h, "tiffconf.h");
    lib.installHeader(tiffvers_h, "tiffvers.h");

    return lib;
}

fn createTiffconfH(
    b: *std.Build,
    platform: zbh.Platform,
    has_zlib: bool,
    has_jpeg: bool,
    has_webp: bool,
    has_zstd: bool,
    has_lzma: bool,
    has_jbig: bool,
    has_lerc: bool,
) std.Build.LazyPath {
    const ssize_type = if (platform.is_windows) "ptrdiff_t" else "ssize_t";
    const bigendian = if (platform.is_big_endian) "1" else "0";

    const content = b.fmt(
        \\/* Configuration defines for installed libtiff. */
        \\#ifndef _TIFFCONF_
        \\#define _TIFFCONF_
        \\
        \\#include <stddef.h>
        \\#include <stdint.h>
        \\#include <inttypes.h>
        \\#ifdef _WIN32
        \\#include <BaseTsd.h>
        \\typedef SSIZE_T ssize_t;
        \\#else
        \\#include <sys/types.h>
        \\#endif
        \\
        \\/* Signed/unsigned integer types */
        \\#define TIFF_INT8_T int8_t
        \\#define TIFF_INT16_T int16_t
        \\#define TIFF_INT32_T int32_t
        \\#define TIFF_INT64_T int64_t
        \\#define TIFF_UINT8_T uint8_t
        \\#define TIFF_UINT16_T uint16_t
        \\#define TIFF_UINT32_T uint32_t
        \\#define TIFF_UINT64_T uint64_t
        \\#define TIFF_SSIZE_T {s}
        \\
        \\#define HAVE_IEEEFP 1
        \\#define HOST_FILLORDER FILLORDER_LSB2MSB
        \\#define HOST_BIGENDIAN {s}
        \\
        \\/* Codec support */
        \\#define CCITT_SUPPORT 1
        \\{s}
        \\#define LOGLUV_SUPPORT 1
        \\#define LZW_SUPPORT 1
        \\#define NEXT_SUPPORT 1
        \\{s}
        \\#define PACKBITS_SUPPORT 1
        \\{s}
        \\#define THUNDER_SUPPORT 1
        \\{s}
        \\{s}
        \\{s}
        \\{s}
        \\{s}
        \\{s}
        \\
        \\#define STRIPCHOP_DEFAULT TIFF_STRIPCHOP
        \\#define SUBIFD_SUPPORT 1
        \\#define DEFAULT_EXTRASAMPLE_AS_ALPHA 1
        \\#define CHECK_JPEG_YCBCR_SUBSAMPLING 1
        \\#define MDI_SUPPORT 1
        \\
        \\/* Compatibility macros (obsolete but kept for backward compatibility) */
        \\#define COLORIMETRY_SUPPORT
        \\#define YCBCR_SUPPORT
        \\#define CMYK_SUPPORT
        \\#define ICC_SUPPORT
        \\#define PHOTOSHOP_SUPPORT
        \\#define IPTC_SUPPORT
        \\
        \\#endif /* _TIFFCONF_ */
        \\
    , .{
        ssize_type,
        bigendian,
        if (has_jpeg) "#define JPEG_SUPPORT 1" else "/* JPEG_SUPPORT disabled */",
        if (has_jpeg) "#define OJPEG_SUPPORT 1" else "/* OJPEG_SUPPORT disabled */",
        if (has_zlib) "#define PIXARLOG_SUPPORT 1" else "/* PIXARLOG_SUPPORT disabled */",
        if (has_zlib) "#define ZIP_SUPPORT 1" else "/* ZIP_SUPPORT disabled */",
        if (has_jbig) "#define JBIG_SUPPORT 1" else "/* JBIG_SUPPORT disabled */",
        if (has_lerc) "#define LERC_SUPPORT 1" else "/* LERC_SUPPORT disabled */",
        if (has_lzma) "#define LZMA_SUPPORT 1" else "/* LZMA_SUPPORT disabled */",
        if (has_zstd) "#define ZSTD_SUPPORT 1" else "/* ZSTD_SUPPORT disabled */",
        if (has_webp) "#define WEBP_SUPPORT 1" else "/* WEBP_SUPPORT disabled */",
    });

    const wf = b.addWriteFiles();
    return wf.add("tiffconf.h", content);
}

fn createTifConfigH(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    platform: zbh.Platform,
    has_zlib: bool,
    has_jpeg: bool,
    has_webp: bool,
    has_zstd: bool,
    has_lzma: bool,
    has_jbig: bool,
    has_lerc: bool,
) *std.Build.Step.ConfigHeader {
    _ = has_zlib;
    _ = has_jpeg;
    return b.addConfigHeader(.{
        .style = .{ .autoconf_undef = upstream.path("libtiff/tif_config.h.in") },
        .include_path = "tif_config.h",
    }, .{
        .CCITT_SUPPORT = 1,
        .CHECK_JPEG_YCBCR_SUBSAMPLING = 1,
        .CHUNKY_STRIP_READ_SUPPORT = null,
        .CXX_SUPPORT = null,
        .DEFER_STRILE_LOAD = null,
        .HAVE_ASSERT_H = 1,
        .HAVE_DECL_OPTARG = zbh.Config.boolToOptInt(platform.is_posix),
        .HAVE_FCNTL_H = zbh.Config.boolToOptInt(platform.is_posix),
        .HAVE_FSEEKO = zbh.Config.boolToOptInt(platform.is_posix),
        .HAVE_GETOPT = zbh.Config.boolToOptInt(platform.is_posix),
        .HAVE_GLUT_GLUT_H = null,
        .HAVE_GL_GLUT_H = null,
        .HAVE_GL_GLU_H = null,
        .HAVE_GL_GL_H = null,
        .HAVE_IO_H = zbh.Config.boolToOptInt(platform.is_windows),
        .HAVE_JBG_NEWLEN = zbh.Config.boolToOptInt(has_jbig),
        .HAVE_MMAP = zbh.Config.boolToOptInt(platform.is_unix),
        .HAVE_OPENGL_GLU_H = null,
        .HAVE_OPENGL_GL_H = null,
        .HAVE_SETMODE = zbh.Config.boolToOptInt(platform.is_windows),
        .HAVE_SNPRINTF = 1,
        .HAVE_STRINGS_H = zbh.Config.boolToOptInt(platform.is_posix),
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_UNISTD_H = zbh.Config.boolToOptInt(platform.is_posix),
        .JPEG_DUAL_MODE_8_12 = null,
        .HAVE_JPEGTURBO_DUAL_MODE_8_12 = null,
        .LERC_SUPPORT = zbh.Config.boolToOptInt(has_lerc),
        .LERC_STATIC = null,
        .LIBJPEG_12_PATH = null,
        .LZMA_SUPPORT = zbh.Config.boolToOptInt(has_lzma),
        .PACKAGE = "libtiff",
        .PACKAGE_BUGREPORT = "tiff@lists.osgeo.org",
        .PACKAGE_NAME = "LibTIFF",
        .PACKAGE_TARNAME = "tiff",
        .PACKAGE_URL = "https://libtiff.gitlab.io/libtiff/",
        .SIZEOF_SIZE_T = @as(i32, @intCast(platform.ptr_width / 8)),
        .STRIP_SIZE_DEFAULT = 8192,
        .TIFF_MAX_DIR_COUNT = 1048576,
        .USE_WIN32_FILEIO = zbh.Config.boolToOptInt(platform.is_windows),
        .WEBP_SUPPORT = zbh.Config.boolToOptInt(has_webp),
        .WORDS_BIGENDIAN = zbh.Config.boolToOptInt(platform.is_big_endian),
        .ZSTD_SUPPORT = zbh.Config.boolToOptInt(has_zstd),
        ._FILE_OFFSET_BITS = null,
        ._LARGEFILE_SOURCE = null,
        ._LARGE_FILES = null,
    });
}

fn createLibportConfigH(b: *std.Build, platform: zbh.Platform) std.Build.LazyPath {
    const content = b.fmt(
        \\#ifndef _LIBPORT_CONFIG_H_
        \\#define _LIBPORT_CONFIG_H_
        \\
        \\#define HAVE_GETOPT {d}
        \\#define HAVE_UNISTD_H {d}
        \\
        \\#endif /* _LIBPORT_CONFIG_H_ */
        \\
    , .{ @as(i32, if (platform.is_posix) 1 else 0), @as(i32, if (platform.is_posix) 1 else 0) });
    const wf = b.addWriteFiles();
    return wf.add("libport_config.h", content);
}

fn createTiffversH(b: *std.Build) std.Build.LazyPath {
    const wf = b.addWriteFiles();
    const content =
        \\#define TIFFLIB_VERSION_STR "LIBTIFF, Version 4.7.1\nCopyright (c) 1988-1996 Sam Leffler\nCopyright (c) 1991-1996 Silicon Graphics, Inc."
        \\#define TIFFLIB_VERSION 20250101
        \\#define TIFFLIB_MAJOR_VERSION 4
        \\#define TIFFLIB_MINOR_VERSION 7
        \\#define TIFFLIB_MICRO_VERSION 1
        \\#define TIFFLIB_VERSION_STR_MAJ_MIN_MIC "4.7.1"
        \\#define TIFFLIB_AT_LEAST(major, minor, micro) \
        \\    (TIFFLIB_MAJOR_VERSION > (major) || \
        \\     (TIFFLIB_MAJOR_VERSION == (major) && TIFFLIB_MINOR_VERSION > (minor)) || \
        \\     (TIFFLIB_MAJOR_VERSION == (major) && TIFFLIB_MINOR_VERSION == (minor) && \
        \\      TIFFLIB_MICRO_VERSION >= (micro)))
        \\
    ;
    return wf.add("tiffvers.h", content);
}

fn addCiTargets(b: *std.Build, ci_step: *std.Build.Step) void {
    const ci_version = zbh.Dependencies.extractVersionFromUrl(build_zon.dependencies.upstream.url) orelse build_zon.version;

    const write_version = b.addWriteFiles();
    _ = write_version.add("version", ci_version);
    ci_step.dependOn(&b.addInstallFile(write_version.getDirectory().path(b, "version"), "version").step);

    const install_path = b.getInstallPath(.prefix, ".");

    for (zbh.Ci.standard) |target_str| {
        const target = zbh.Ci.resolve(b, target_str);
        const ci_platform = zbh.Platform.detect(target.result);
        const upstream = b.dependency("upstream", .{});

        const has_zlib = true;
        const has_jpeg = true;
        const has_webp = false;
        const has_zstd = false;
        const has_lzma = false;
        const has_jbig = false;
        const has_lerc = false;

        const lib = buildLibrary(b, target, .ReleaseFast, upstream, .static, .static, .static, .none, .none, .none, .none, .none);

        const archive_root = b.fmt("libtiff-{s}-{s}", .{ ci_version, target_str });
        const target_lib_dir: std.Build.InstallDir = .{ .custom = b.fmt("{s}/lib", .{archive_root}) };
        const target_include_dir: std.Build.InstallDir = .{ .custom = b.fmt("{s}/include", .{archive_root}) };
        const target_bin_dir: std.Build.InstallDir = .{ .custom = b.fmt("{s}/bin", .{archive_root}) };

        const install_lib = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = target_lib_dir } });
        const install_tiff_h = b.addInstallFileWithDir(upstream.path("libtiff/tiff.h"), target_include_dir, "tiff.h");
        const install_tiffio_h = b.addInstallFileWithDir(upstream.path("libtiff/tiffio.h"), target_include_dir, "tiffio.h");

        const tiffconf_h = createTiffconfH(b, ci_platform, has_zlib, has_jpeg, has_webp, has_zstd, has_lzma, has_jbig, has_lerc);
        const tiffvers_h = createTiffversH(b);
        const install_tiffconf_h = b.addInstallFileWithDir(tiffconf_h, target_include_dir, "tiffconf.h");
        const install_tiffvers_h = b.addInstallFileWithDir(tiffvers_h, target_include_dir, "tiffvers.h");

        var install_tool_steps: [core_tool_defs.len]?*std.Build.Step.InstallArtifact = [_]?*std.Build.Step.InstallArtifact{null} ** core_tool_defs.len;

        if (!ci_platform.is_windows) {
            const tif_config_h = createTifConfigH(
                b,
                upstream,
                ci_platform,
                has_zlib,
                has_jpeg,
                has_webp,
                has_zstd,
                has_lzma,
                has_jbig,
                has_lerc,
            );
            const libport_config = createLibportConfigH(b, ci_platform);
            const cflags = &[_][]const u8{"-w"};

            for (core_tool_defs, 0..) |tool, i| {
                const exe = b.addExecutable(.{
                    .name = tool.name,
                    .root_module = b.createModule(.{ .target = target, .optimize = .ReleaseFast, .link_libc = true }),
                });
                exe.addIncludePath(upstream.path("libtiff"));
                exe.addIncludePath(upstream.path("port"));
                exe.addIncludePath(libport_config.dirname());
                exe.addConfigHeader(tif_config_h);
                exe.addCSourceFile(.{ .file = upstream.path(tool.src), .flags = cflags });
                exe.linkLibrary(lib);
                exe.linkSystemLibrary("m");
                install_tool_steps[i] = b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = target_bin_dir } });
            }
        }

        const archive = zbh.Archive.create(b, archive_root, ci_platform.is_windows, install_path);
        archive.step.dependOn(&install_lib.step);
        archive.step.dependOn(&install_tiff_h.step);
        archive.step.dependOn(&install_tiffio_h.step);
        archive.step.dependOn(&install_tiffconf_h.step);
        archive.step.dependOn(&install_tiffvers_h.step);
        for (install_tool_steps) |maybe_step| {
            if (maybe_step) |step| archive.step.dependOn(&step.step);
        }
        ci_step.dependOn(&archive.step);
    }
}

fn parseVersion(ver: []const u8) struct { major: u32, minor: u32, patch: u32 } {
    var parts: [3]u32 = .{ 0, 0, 0 };
    var iter = std.mem.splitScalar(u8, ver, '.');
    var i: usize = 0;
    while (iter.next()) |part| : (i += 1) {
        if (i >= 3) break;
        parts[i] = std.fmt.parseInt(u32, part, 10) catch 0;
    }
    return .{ .major = parts[0], .minor = parts[1], .patch = parts[2] };
}
