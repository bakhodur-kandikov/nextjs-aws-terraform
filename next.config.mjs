
/** @type {import('next').NextConfig} */
const nextConfig = {
    output: "standalone",
    images: {
        loader: 'custom',
        loaderFile: './src/utils/cloudfrontLoader.ts',
    },
};

export default nextConfig;
