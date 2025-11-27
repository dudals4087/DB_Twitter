<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="true"%>
<%
    // 혹시 문자 인코딩 설정이 문제를 일으키는 경우를 피하기 위해 생략

    try {
        // 세션이 살아있으면 전부 날리기
        if (session != null) {
            session.invalidate();
        }

        // 메인 화면으로 이동
        response.sendRedirect("main.jsp");
        return;
    } catch (Exception e) {
        // 혹시 모를 예외는 서버 로그로만 남기고
        e.printStackTrace();
    }
%>
