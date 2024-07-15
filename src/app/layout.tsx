import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Planets",
  description: "Wonderful planets!",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html className="h-full w-full bg-white" lang="en">
      <body className="h-full w-full">{children}</body>
    </html>
  );
}
