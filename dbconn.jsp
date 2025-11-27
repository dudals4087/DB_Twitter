<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.sql.*" %>
<%
    // 모든 JSP에서 공통으로 쓸 DB 연결 객체
    Connection con = null;

    try {
        // MySQL 드라이버 로드
        Class.forName("com.mysql.cj.jdbc.Driver");

        // DB 연결 정보
        String url  = "jdbc:mysql://localhost:3306/twitter?useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC";
        String user = "root";
        String pass = "12345";

        // 커넥션 생성
        con = DriverManager.getConnection(url, user, pass);

    } catch (Exception e) {
        // 여기서 에러 나면 JSP는 뜨는데 DB 쪽에서만 500이 나게 됨
        e.printStackTrace();
        throw new RuntimeException("DB 연결 중 오류  " + e.getMessage(), e);
    }
%>
