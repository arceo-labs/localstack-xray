import * as fs from "fs";
import JSZip from "jszip";
import * as path from "path";
import TerserPlugin from "terser-webpack-plugin";
import type {Compiler, Configuration, Stats, WebpackPluginInstance} from "webpack";
import "webpack";
import {BundleAnalyzerPlugin} from "webpack-bundle-analyzer";

async function onCompileDone(stats: Stats) {
    const {path: outputDir, filename: outputJsName} = stats.compilation.options.output;

    if (outputDir === undefined) {
        throw Error();
    }
    if (outputJsName === undefined || typeof outputJsName !== "string") {
        throw Error();
    }

    const outputJsPath = path.join(outputDir, outputJsName);
    const outputMapName = `${outputJsName}.map`;
    const outputMapPath = path.join(outputDir, outputMapName);
    const outputZipName = outputJsName.replace(/\.js$/, ".zip");

    function onFinish() {
        console.error(`${outputZipName} written`);
    }

    const zip = new JSZip();
    try {
        const innerZipFileTimestamp = new Date(Date.UTC(1980, 0, 1, 0, 0, 0));
        const options: JSZip.JSZipGeneratorOptions<"nodebuffer"> = {
            type: "nodebuffer",
            streamFiles: true,
            compression: "DEFLATE",
            compressionOptions: {level: 9},
        };
        const stream = fs.createWriteStream(path.join(outputDir, outputZipName));
        zip.file(outputJsName, fs.readFileSync(outputJsPath), {date: innerZipFileTimestamp});
        zip.file(outputMapName, fs.readFileSync(outputMapPath), {date: innerZipFileTimestamp});
        zip.generateNodeStream(options).pipe(stream).on("finish", onFinish);
    } catch (err) {
        console.error(`${err}`);
        throw err;
    }
}

class ZipLambda implements WebpackPluginInstance {
    apply(compiler: Compiler) {
        return compiler.hooks.done.tapPromise("ZipLambda", onCompileDone);
    }
}

function createWebpackConfig(directory: string, tsFilename: string): Configuration {
    const jsFilename = tsFilename.replace(/\.ts$/, ".js");
    const outputDir = path.join(directory, "dist");
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir);
    }
    return {
        entry: [path.join(directory, "src", tsFilename)],
        target: "node",
        externals: [
            "aws-crt",
            "@aws-sdk/signature-v4-crt",
            "@napi-rs/snappy-win32-x64-msvc",
            "@napi-rs/snappy-darwin-x64",
            "@napi-rs/snappy-linux-x64-gnu",
            "@napi-rs/snappy-linux-x64-musl",
            "@napi-rs/snappy-linux-arm64-gnu",
            "@napi-rs/snappy-win32-ia32-msvc",
            "@napi-rs/snappy-linux-arm-gnueabihf",
            "@napi-rs/snappy-darwin-arm64",
            "@napi-rs/snappy-android-arm64",
            "@napi-rs/snappy-android-arm-eabi",
            "@napi-rs/snappy-freebsd-x64",
            "@napi-rs/snappy-linux-arm64-musl",
            "@napi-rs/snappy-win32-arm64-msvc",
        ],
        output: {path: outputDir, filename: jsFilename, library: {type: "umd"}},
        resolve: {
            extensions: [".js", ".ts"],
            extensionAlias: {".js": [".js", ".ts"], ".cjs": [".cjs", ".cts"], ".mjs": [".mjs", ".mts"]},
        },
        module: {
            rules: [
                {test: /\.([cm]?ts|tsx)$/, use: "ts-loader"},
                {test: /\.[jt]sx?\.map$/, use: {loader: "file-loader"}},
            ],
        },
        optimization: {
            minimize: false,
            minimizer: [new TerserPlugin({terserOptions: {keep_fnames: /AbortSignal/}})],
        },
        plugins: [
            new BundleAnalyzerPlugin({
                analyzerMode: "static",
                openAnalyzer: false,
                reportFilename: path.join(outputDir, tsFilename.replace(/\.ts$/, ".html")),
            }),
            new ZipLambda(),
        ],
        // stats: "detailed",
        // stats: "normal",
        // stats: "summary",
        // mode: "development",
        // optimization: {minimize: false},
        devtool: "source-map",
        stats: "normal",
        mode: "development",
    };
}

export default createWebpackConfig;
