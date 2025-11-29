<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*, java.text.SimpleDateFormat" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    
    // [수정] 세션 변수명을 'currentUserPaid'로 통일하여 구독 상태를 올바르게 가져옴
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    // 비로그인 시 로그인 페이지로 이동
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    
    String currentInitial = (currentUser != null && currentUser.length() > 0) ?
                            currentUser.substring(0,1).toUpperCase() : "G";
    
    // 결제 관련 예시 변수
    String defaultCardNum = "1111-2222-3333-4444";
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>구독 결제 / TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        .payment-input {
            padding: 12px 12px 12px 40px !important;
        }
        .payment-center-layout {
            display: flex;
            justify-content: center;
            align-items: flex-start;
            min-height: 90vh;
            padding-top: 50px;
        }
        .payment-card {
            max-width: 450px;
            width: 100%;
            background-color: #ffffff;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            padding: 30px;
        }
    </style>
</head>
<body style="background-color: #f7f9f9;">
<div class="app-shell">

    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">결제</div>
        </div>
        <div class="app-header-right">
            <% if (currentUser != null) { %>
                <a href="settings.jsp" class="icon-btn" title="설정"><i class="fa-solid fa-gear"></i></a>
            <% } %>
        </div>
    </header>

    <div class="payment-center-layout">
        <div class="payment-card">
            
            <h2 class="section-title" style="font-size: 24px; text-align: center; margin-bottom: 25px;">
                TWITTER_DB4 구독 결제
            </h2>

            <div style="display:flex; align-items:center; gap:10px; margin-bottom: 20px; padding-bottom: 15px; border-bottom: 1px solid #eee;">
                <div class="avatar-sm"><%= currentInitial %></div>
                <div style="font-weight: 600;"><%= currentUser %>님의 계정</div>
                
                <% if (currentPaid) { %>
                    <span class="badge-check" style="margin-left: 5px;">✓</span>
                <% } %>
            </div>

            <form method="post" action="processSubscription.jsp">
                
                <div class="form-field">
                    <div class="form-label">구독 기간 선택</div>
                    <select name="subscription_plan" class="input-text" style="padding-left: 10px;">
                        <option value="monthly">월간 구독 (12,000원)</option>
                        <option value="yearly">연간 구독 (120,000원)</option>
                    </select>
                </div>

                <div class="form-field">
                    <div class="form-label">카드 번호</div>
                    <div class="input-wrapper-icon">
                        <i class="fa-solid fa-credit-card icon-inside-input"></i>
                        <input type="text" name="card_number" class="input-text payment-input has-icon" 
                               placeholder="예: 1234-5678-xxxx-xxxx" value="<%= defaultCardNum %>" required>
                    </div>
                </div>

                <div style="display: flex; gap: 15px;">
                    <div class="form-field" style="flex: 1;">
                        <div class="form-label">유효기간 (MM/YY)</div>
                        <div class="input-wrapper-icon">
                            <i class="fa-solid fa-calendar icon-inside-input"></i>
                            <input type="text" name="card_expiry" class="input-text payment-input has-icon" placeholder="MM/YY" required>
                        </div>
                    </div>
                    
                    <div class="form-field" style="flex: 1;">
                        <div class="form-label">CVC</div>
                        <div class="input-wrapper-icon">
                            <i class="fa-solid fa-lock icon-inside-input"></i>
                            <input type="text" name="card_cvc" class="input-text payment-input has-icon" placeholder="CVC" required>
                        </div>
                    </div>
                </div>

                <div class="helper-text" style="margin-top: 20px; text-align: center;">
                    결제 금액에는 VAT가 포함되어 있으며, 언제든지 구독을 취소할 수 있습니다.
                </div>

                <button type="submit" class="btn-primary" style="width: 100%; padding: 12px; font-size: 16px; margin-top: 25px;">
                    결제하기 (구독 시작)
                </button>
            </form>

            <div style="text-align: center; margin-top : 15px;">
                <a href="settings.jsp" style="color: #536471; font-size: 14px; text-decoration: none; transition: color 0.2s;">
                    설정으로 돌아가기
                </a>
            </div>
        </div>
    </div>
</div>
</body>
</html>